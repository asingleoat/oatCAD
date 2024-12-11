
      const canvas = document.createElement('canvas');
      document.body.appendChild(canvas);
      const engine = new BABYLON.Engine(canvas, true);
      const scene = new BABYLON.Scene(engine);
      scene.clearColor = new BABYLON.Color4(0.8, 0.8, 0.8, 1); // Light gray with full opacity
      const camera = new BABYLON.ArcRotateCamera("Camera", Math.PI / 2, Math.PI / 2, 5, BABYLON.Vector3.Zero(), scene);
      camera.attachControl(canvas, true);
      const light = new BABYLON.HemisphericLight("Light", new BABYLON.Vector3(1, 1, 0), scene);
      // Placeholder for the mesh
      let dynamicMesh;
      // Function to update or create the mesh
      function updateMesh(data) {
        const vertices = new Float32Array(data.vertices);
        const indices = new Uint16Array(data.indices);
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
          material.diffuseColor = new BABYLON.Color3(1, 0, 0); // Red
          // material.backFaceCulling = false; // Render both sides
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
                    updateMesh(data);
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

        connectWebSocket(); // Initial connection attempt

      // Render loop
      engine.runRenderLoop(() => {
        scene.render();
      });
      // Resize event
      window.addEventListener('resize', () => {
        engine.resize();
      });
