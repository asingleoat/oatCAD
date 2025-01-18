const canvas = document.createElement('canvas');
document.body.appendChild(canvas);

const engine = new BABYLON.Engine(canvas, true, { antialias: true });
const scene = new BABYLON.Scene(engine);

scene.clearColor = new BABYLON.Color4(0.8, 0.8, 0.8, 1);       // Light gray with full opacity

const camera = new BABYLON.ArcRotateCamera("Camera", Math.PI / 2, Math.PI / 2, 5, BABYLON.Vector3.Zero(), scene);
camera.attachControl(canvas, true);
camera.mode = BABYLON.Camera.ORTHOGRAPHIC_CAMERA;
function updateCameraAspect(camera, canvas) {
    const aspectRatio = canvas.width / canvas.height;
    const viewHeight = 10; // Total height of the orthographic view (orthoTop - orthoBottom)
    
    camera.orthoTop = viewHeight / 2;
    camera.orthoBottom = -viewHeight / 2;
    camera.orthoLeft = -viewHeight / 2 * aspectRatio;
    camera.orthoRight = viewHeight / 2 * aspectRatio;
}
// Set the initial aspect ratio
updateCameraAspect(camera, canvas);

enableOrthographicZoom(camera, canvas, 0.1);

const pipeline = new BABYLON.DefaultRenderingPipeline("default", true, scene, [camera]);
// msaa
pipeline.samples = 16;

// screen space antialiasing, breaks wireframe color for some reason?
// const fxaa = new BABYLON.FxaaPostProcess("fxaa", 2.0, camera);

const light = new BABYLON.HemisphericLight("Light", new BABYLON.Vector3(1, 1, 0), scene);

function renderModel(data) {
    switch (data.modelType) {
    case "line":
        updatePolylines(data);
        break;
    case "mesh":
        updateMesh(data);
        break;
    default:
        updateMesh(data);
        console.error("Unknown modelType:", jsonData.modelType);
        break;
    }
}

const dynamicLines = [];
function updatePolylines(data) {
    const newPolylines = data.lines;

    // Dispose of all currently rendered polylines
    for (const line of dynamicLines) {
        line.dispose();
    }
    dynamicLines.length = 0;

    for (const polylineData of newPolylines) {
        const flatVertices = new Float32Array(polylineData);

        const points = unflattenVertices(flatVertices);

        const line = BABYLON.MeshBuilder.CreateLines("dynamicLine", {
            points: points,
            updatable: true,
        }, scene);
        const baseColor = new BABYLON.Color3(0.8, 0.8, 0.8);
        const randomColor = getRandomColorWithContrast(baseColor, 2.5);
        line.color = randomColor;
        dynamicLines.push(line);
    }

}

function getRandomColor() {
    return new BABYLON.Color3(
        Math.random(),
        Math.random(),
        Math.random()
    );
}

function calculateContrast(color1, color2) {
    const luminance = (color) => {
        const r = color.r <= 0.03928 ? color.r / 12.92 : Math.pow((color.r + 0.055) / 1.055, 2.4);
        const g = color.g <= 0.03928 ? color.g / 12.92 : Math.pow((color.g + 0.055) / 1.055, 2.4);
        const b = color.b <= 0.03928 ? color.b / 12.92 : Math.pow((color.b + 0.055) / 1.055, 2.4);
        return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    };

    const l1 = luminance(color1) + 0.05;
    const l2 = luminance(color2) + 0.05;

    // contrast ratio
    return l1 > l2 ? l1 / l2 : l2 / l1;
}

function getRandomColorWithContrast(baseColor, minContrast = 1.5) {
    let color;
    do {
        color = getRandomColor();
    } while (calculateContrast(color, baseColor) < minContrast);
    return color;
}

function unflattenVertices(flatVertices) {
    const grouped = [];
    for (let i = 0; i < flatVertices.length; i += 3) {
        grouped.push(new BABYLON.Vector3(flatVertices[i], flatVertices[i + 1], flatVertices[i + 2]));
    }
    return grouped;
}

let dynamicMesh;
function updateMesh(data) {
	const vertices = new Float32Array(data.vertices);
	const indices = new Uint32Array(data.indices);
	if (dynamicMesh) {
		// update existing mesh
		const vertexData = new BABYLON.VertexData();
		vertexData.positions = Array.from(vertices);
		vertexData.indices = Array.from(indices);
		vertexData.applyToMesh(dynamicMesh);
	} else {
		// create new mesh
		const vertexData = new BABYLON.VertexData();
		vertexData.positions = Array.from(vertices);
		vertexData.indices = Array.from(indices);
		dynamicMesh = new BABYLON.Mesh("dynamicMesh", scene);
		vertexData.applyToMesh(dynamicMesh);
		const material = new BABYLON.StandardMaterial("material", scene);
		// material.diffuseColor = new BABYLON.Color3(1, 0, 0); // Red
		material.diffuseColor = new BABYLON.Color3(0.094, 0.604, 0.706); // Red
    // weaken highlights
    material.specularColor = new BABYLON.Color3(0.2,0.2,0.2);
		// material.backFaceCulling = false;
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
    // console.log("Raw WebSocket message:", event.data);
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

connectWebSocket();

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

engine.runRenderLoop(() => {
	scene.render();
});

window.addEventListener('resize', () => {
	  engine.resize();
    updateCameraAspect(camera, canvas);
});

function enableOrthographicZoom(camera, canvas, zoomSpeed = 0.1) {
    canvas.addEventListener("wheel", function (event) {
        event.preventDefault();

        const delta = event.deltaY > 0 ? 1 : -1; // Scroll direction
        const zoomFactor = 1 + delta * zoomSpeed;

        camera.orthoLeft *= zoomFactor;
        camera.orthoRight *= zoomFactor;
        camera.orthoTop *= zoomFactor;
        camera.orthoBottom *= zoomFactor;
    });
}
