package aerys.minko.type.collada.store
{
	import aerys.minko.type.vertex.VertexIterator;

	public class Triangles
	{
		private static const NS : Namespace = 
			new Namespace("http://www.collada.org/2005/11/COLLADASchema");
		
		private const NOT_YET_IMPLEMENTED_FAIL : Function = 
			function(xmlPrimitive : XML) : void { throw new Error(xmlPrimitive.localName() + ' primitives are not supported yet'); };
		
		private const NAME_TO_PARSER : Object = {
			'lines'			: NOT_YET_IMPLEMENTED_FAIL,
			'linestrips'	: NOT_YET_IMPLEMENTED_FAIL,
			'polygons'		: NOT_YET_IMPLEMENTED_FAIL,
			'polylist'		: fillVerticesFromPolylist,
			'triangles'		: fillVerticesFromTriangles,
			'trifans'		: NOT_YET_IMPLEMENTED_FAIL,
			'tristrips'		: NOT_YET_IMPLEMENTED_FAIL
		};
		
		/**
		 * Contains a list of all semantics here 
		 */		
		private var _semantics			: Vector.<String>;
		
		/**
		 * We have to store this because there are two kinds of &lt;input&gt; nodes (shared and unshared) 
		 * 
		 * _offsets[semantic] = uint 
		 */
		private var _offsets			: Object;
		
		/**
		 * _sources[semantic] = Source 
		 */		
		private var _sources			: Object;
		
		/**
		 * as ids can be shared, this tells really how many ids are they
		 * per vertex.
		 */		
		private var _indicesPerVertex	: uint;
		
		/**
		 * Contains all ids (triangulated).
		 */		
		private var _triangleVertices	: Vector.<uint>;
		
		
		public function get semantics()			: Vector.<String>	{ return _semantics; }
		public function get indicesPerVertex()	: uint				{ return _indicesPerVertex; }
		public function get vertexCount()		: uint				{ return _triangleVertices.length / _indicesPerVertex; }
		public function get triangleCount()		: uint				{ return vertexCount / 3; }
		
		public function Triangles(xmlPrimitive	: XML = null, 
								  xmlMesh		: XML = null)
		{
			if (xmlPrimitive && xmlMesh)
				initializeFromXML(xmlPrimitive, xmlMesh);
		}
		
		/*
		* Fixme
		* There is maybe a misunderstanding reading the collada specifications, and it seams illogical
		* droping this data for the vertex component.
		* 
		* Nevertheless, we already know everything about the vertices.
		* According to the collada 1.5 specs, there is always and only 1 vertices nodes per mesh.
		* cf : Collada, Specification – Core Elements Reference 5-89, so why do we need references to it?
		*/
		private function initializeFromXML(xmlPrimitive	: XML, 
										   xmlMesh		: XML) : void
		{
			_semantics			= new Vector.<String>();
			_offsets			= new Object();
			_sources			= new Object();	
			
			_indicesPerVertex	= 0;
			_triangleVertices	= new Vector.<uint>();
			
			var sources		: XMLList	= xmlMesh..NS::source;
			for each (var input : XML in xmlPrimitive.NS::input)
			{
				var semantic 	: String	= String(input.@semantic);
				var offset		: uint		= parseInt(String(input.@offset));
				var sourceId	: String	= String(input.@source).substr(1);
				
				if (offset + 1 > _indicesPerVertex)
					_indicesPerVertex = offset + 1;
				
				_semantics.push(semantic);
				_offsets[semantic] = offset;
				
				if (semantic != 'VERTEX')
					_sources[semantic] = Source.createFromXML(sources.(@id == sourceId)[0]);
			}
			
			// will triangulate the data in here and push ids to _triangleVertices
			NAME_TO_PARSER[xmlPrimitive.localName()](xmlPrimitive);
			
//			 cf comentary upside.
//			if (_offsets['VERTEX'] == undefined)
//				throw new Error(
//					'Invalid collada file. An input of VERTEX semantic is ' +
//					'mandatory in ' + xmlPrimitive.localName() + ' nodes');
		}
		
		/**
		 * No need for triangulation: just copies data from the p xml node to 
		 * our triangle vector. 
		 */		
		private function fillVerticesFromTriangles(xmlPrimitive : XML) : void
		{
			var indexList : Array = String(xmlPrimitive.NS::p[0]).split(' ');
			for each (var index : String in indexList)
				_triangleVertices.push(parseInt(index));
		}
		
		/**
		 * Triangulate using p and vcount and push data to the triangle vector.
		 */		
		private function fillVerticesFromPolylist(xmlPrimitive : XML) : void
		{
			var indexList 		: Array = String(xmlPrimitive.NS::p[0]).split(' ');
			var polyCountList	: Array = String(xmlPrimitive.NS::vcount[0]).split(' ');
			
			var currentIndex	: uint = 0;
			for each (var polyCount : String in polyCount)
			{
				var numVertices : uint = parseInt(polyCount);
				
				for (var j : uint = 1; j < numVertices - 1; ++j)
				{
					var k : uint;
					for (k = 0; k < _indicesPerVertex; ++k)
						_triangleVertices.push(indexList[currentIndex + k]);
					
					for (k = 0; k < _indicesPerVertex; ++k)
						_triangleVertices.push(indexList[currentIndex + j + k]);
					
					throw new Error('fix me, the last polygon is going to fail when recreating the triangle fan because a modulo is missing');
					for (k = 0; k < _indicesPerVertex; ++k)
						_triangleVertices.push(indexList[(currentIndex + j + _indicesPerVertex + k /* it's missing around here */)]);
				}
				
				currentIndex += numVertices;
			}
		}
		
		
		
		public function getVertexId(storeVertexId : uint) : uint
		{
			return _triangleVertices[storeVertexId * indicesPerVertex + _offsets['VERTEX']];
		}
		
		public function pushVertexComponents(storeVertexId	: uint, 
											 semantics		: Vector.<String>,
											 out			: Vector.<Number>) : void
		{
			var semanticsLength : uint = semantics.length;
			
			for (var semanticId : uint = 0; semanticId < semanticsLength; ++semanticId)
			{
				var semantic 		: String	= semantics[semanticId];
				
				var source			: Source	= _sources[semantic];
				var sourceVertexId	: uint		= _triangleVertices[_indicesPerVertex * storeVertexId + _offsets[semantic]];
				
				source.pushVertexComponent(sourceVertexId, out);
			}
		}
		
	}
}