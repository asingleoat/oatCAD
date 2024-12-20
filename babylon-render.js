const canvas = document.createElement('canvas');
document.body.appendChild(canvas);

const engine = new BABYLON.Engine(canvas, true, { antialias: true });
const scene = new BABYLON.Scene(engine);

scene.clearColor = new BABYLON.Color4(0.8, 0.8, 0.8, 1);       // Light gray with full opacity

const camera = new BABYLON.ArcRotateCamera("Camera", Math.PI / 2, Math.PI / 2, 5, BABYLON.Vector3.Zero(), scene);
camera.attachControl(canvas, true);

const pipeline = new BABYLON.DefaultRenderingPipeline("default", true, scene, [camera]);
// msaa
pipeline.samples = 16;

// screen space antialiasing, breaks wireframe color for some reason?
// const fxaa = new BABYLON.FxaaPostProcess("fxaa", 2.0, camera);

const light = new BABYLON.HemisphericLight("Light", new BABYLON.Vector3(1, 1, 0), scene);

function renderModel(data) {
    switch (data.modelType) {
        case "line":
            updatePolyline(data);
            break;
        case "mesh":
            updateMesh(data);
            break;
        default:
           updateMesh(data);
           console.log("fallthrough");
            break;
            // console.error("Unknown modelType:", jsonData.modelType);
    }
}

// polyline handler
let dynamicLine;
function updatePolyline(data) {
    const flatVertices = new Float32Array(data.vertices);
    const points = unflattenVertices(flatVertices);
    if (dynamicLine) {
        dynamicLine.updateVerticesData(BABYLON.VertexBuffer.PositionKind, points);
    } else {
        const dynamicLine = new BABYLON.MeshBuilder.CreateLines("dynamicLine", { points: points,     updatable: true }, scene);
        dynamicLine.color = new BABYLON.Color3(1, 0, 0);
    }
}
function unflattenVertices(flatVertices) {
    const grouped = [];
    for (let i = 0; i < flatVertices.length; i += 3) {
        grouped.push(new BABYLON.Vector3(flatVertices[i], flatVertices[i + 1], flatVertices[i + 2]));
    }
    return grouped;
}

// 3d mesh handler
let dynamicMesh;
function updateMesh(data) {
	const vertices = new Float32Array(data.vertices);
	const indices = new Uint32Array(data.indices);
	if (dynamicMesh) {
		// Update existing mesh
		const vertexData = new BABYLON.VertexData();
		vertexData.positions = Array.from(vertices);
		vertexData.indices = Array.from(indices);
		vertexData.applyToMesh(dynamicMesh);
	} else {
		// Create new mesh
		const vertexData = new BABYLON.VertexData();
		vertexData.positions = Array.from(vertices);
		vertexData.indices = Array.from(indices);
		dynamicMesh = new BABYLON.Mesh("dynamicMesh", scene);
		vertexData.applyToMesh(dynamicMesh);
		// Apply material with double-sided rendering
		const material = new BABYLON.StandardMaterial("material", scene);
		// material.diffuseColor = new BABYLON.Color3(1, 0, 0); // Red
		material.diffuseColor = new BABYLON.Color3(0.094, 0.604, 0.706); // Red
    // weaken highlights
    material.specularColor = new BABYLON.Color3(0.2,0.2,0.2);
		material.backFaceCulling = false; // Render both sides
		dynamicMesh.material = material;
	}
}

// WebSocket setup with retry logic
let ws = null;
let retryInterval = null;

function connectWebSocket() {
	ws = new WebSocket('ws://localhost:9223');

	ws.onopen = () => {
		console.log('WebSocket connected');
		clearInterval(retryInterval); // Stop retrying once connected
		retryInterval = null;
	};

	ws.onmessage = (event) => {
		try {
			const data = JSON.parse(event.data);
			renderModel(data);
		} catch (e) {
			console.error('Error parsing WebSocket message:', e);
		}
	};

	ws.onerror = (error) => {
		console.error('WebSocket error:', error);
	};

	ws.onclose = () => {
		console.log('WebSocket closed, retrying...');
		if (!retryInterval) {
			retryInterval = setInterval(() => connectWebSocket(), 1000);
		}
	};
}

connectWebSocket();         // Initial connection attempt
// scene.onPointerObservable.add(() => {
//     isWireframe = !isWireframe;
//     material.wireframe = isWireframe;
// });

let isWireframe = false;
scene.onPointerObservable.add((pointerInfo) => {
    if (pointerInfo.type === BABYLON.PointerEventTypes.POINTERPICK) {
        const pickedMesh = pointerInfo.pickInfo.pickedMesh;
        if (pickedMesh) {
            // pickedMesh.material.diffuseColor = new BABYLON.Color3(1, 1, 0); // Change to red
            console.log("Picked mesh:", pickedMesh.name);
            isWireframe = !isWireframe;
            pickedMesh.material.wireframe = isWireframe;

        }
    }
});


// test polyline rendering
//
// const points = [
//     new BABYLON.Vector3(0, 0, 0),
//     new BABYLON.Vector3(1, 1, 0),
//     new BABYLON.Vector3(2, 0, 0),
//     new BABYLON.Vector3(3, 1, 0),
//     new BABYLON.Vector3(0, 0, 0),
// ];

// const polyline = BABYLON.MeshBuilder.CreateLines("polyline", { points: points }, scene);

// const material = new BABYLON.StandardMaterial("lineMaterial", scene);
// material.emissiveColor = new BABYLON.Color3(1, 0, 0); // Red line
// polyline.material = material;

// Render loop
engine.runRenderLoop(() => {
	scene.render();
});
// Resize event
window.addEventListener('resize', () => {
	engine.resize();
});
