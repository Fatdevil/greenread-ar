/* ============================================
   GreenRead AR — Main Application Controller
   Orchestrates Three.js scene, user interactions,
   HUD updates, and state management
   ============================================ */

(function() {
  'use strict';

  // ============ APP STATE ============
  const State = {
    SPLASH: 'splash',
    SCANNING: 'scanning',
    PLACE_HOLE: 'place_hole',
    PLACE_BALL: 'place_ball',
    READY: 'ready',
    ROLLING: 'rolling',
    RESULT: 'result'
  };

  const App = {
    state: State.SPLASH,
    scene: null,
    camera: null,
    renderer: null,
    terrain: null,
    physics: null,
    raycaster: new THREE.Raycaster(),
    mouse: new THREE.Vector2(),

    // Entities
    holeMarker: null,
    holePosition: null,
    ballMesh: null,
    ballPosition: null,
    trailLine: null,
    breakCurveLine: null,

    // Settings
    settings: {
      stimp: 10.0,
      unit: 'metric',
      breakUnit: 'cm',
      numBalls: 1,
    },

    // Animation
    clock: new THREE.Clock(),
    scanProgress: 0,
    trailPositions: [],
    trailOpacities: [],
  };

  // ============ INIT ============
  function init() {
    setupEventListeners();
  }

  async function initScene() {
    const canvas = document.getElementById('ar-canvas');

    // Renderer
    App.renderer = new THREE.WebGLRenderer({
      canvas: canvas,
      antialias: true,
      alpha: true, // MUST be true for video to show through!
    });
    App.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    App.renderer.setSize(window.innerWidth, window.innerHeight);
    App.renderer.shadowMap.enabled = true;
    App.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    App.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    App.renderer.toneMappingExposure = 1.0;
    App.renderer.outputEncoding = THREE.sRGBEncoding;

    // Scene
    App.scene = new THREE.Scene();
    // Inget bakgrundsfärg! Måste vara helt transparent för AR
    App.scene.background = null; 
    // Dimman skapar problem i AR
    App.scene.fog = null;

    // Camera — elevated angle looking down at the green
    App.camera = new THREE.PerspectiveCamera(50, window.innerWidth / window.innerHeight, 0.1, 100);
    App.camera.position.set(0, 6, 8);
    App.camera.lookAt(0, 0, -1);

    // Lights
    const ambientLight = new THREE.AmbientLight(0x404040, 0.6);
    App.scene.add(ambientLight);

    const mainLight = new THREE.DirectionalLight(0xFFF8E7, 1.2);
    mainLight.position.set(5, 10, 5);
    mainLight.castShadow = true;
    mainLight.shadow.mapSize.width = 2048;
    mainLight.shadow.mapSize.height = 2048;
    mainLight.shadow.camera.near = 0.5;
    mainLight.shadow.camera.far = 30;
    mainLight.shadow.camera.left = -10;
    mainLight.shadow.camera.right = 10;
    mainLight.shadow.camera.top = 10;
    mainLight.shadow.camera.bottom = -10;
    App.scene.add(mainLight);

    const fillLight = new THREE.DirectionalLight(0x3B82F6, 0.15);
    fillLight.position.set(-5, 3, -5);
    App.scene.add(fillLight);

    const rimLight = new THREE.DirectionalLight(0x1A7A4A, 0.2);
    rimLight.position.set(0, 2, -8);
    App.scene.add(rimLight);

    // Ground plane (dark underneath the green mesh)
    // Sänker alpha på skuggbakgrunden så vi ser gräset i kameran
    const groundGeom = new THREE.PlaneGeometry(50, 50);
    const groundMat = new THREE.MeshStandardMaterial({
      color: 0x0A1A0F,
      roughness: 1,
      transparent: true,
      opacity: 0.15 
    });
    const ground = new THREE.Mesh(groundGeom, groundMat);
    ground.rotation.x = -Math.PI / 2;
    ground.position.y = -0.05;
    ground.receiveShadow = true;
    App.scene.add(ground);

    // Generate terrain
    App.terrain = new GreenTerrain(App.scene);
    try {
        await App.terrain.loadFromJSON('data/heightmap.json');
        App.dataSource = 'lantmateriet';
    } catch (e) {
        console.error("Could not load LiDAR data, falling back to procedural:", e);
        App.terrain.generate();
        App.dataSource = 'procedural';
    }

    // Init physics
    App.physics = new BallPhysics(App.terrain);
    App.physics.setStimpmeter(App.settings.stimp);

    // Start animation loop
    animate();

    // Start real camera
    await startCamera();

    // Simulate scanning
    simulateScanning();
  }

  // ============ CAMERA STREAM ============
  async function startCamera() {
    try {
      const video = document.getElementById('ar-video');
      // Begär enhetens bakre kamera (environment)
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "environment" },
        audio: false
      });
      video.srcObject = stream;
    } catch (err) {
      console.error("Kamera-åtkomst nekades eller enhet saknas: ", err);
      // Fallback: Låt koden köra vidare men bakgrunden förblir svart
      document.getElementById('ar-video').style.background = "#121212";
    }
  }

  // ============ SCANNING ANIMATION ============
  function simulateScanning() {
    App.state = State.SCANNING;
    const badge = document.getElementById('scan-badge');
    const scanText = document.getElementById('scan-text');
    const slopeHud = document.getElementById('slope-hud');

    // Animate grid appearing gradually
    if (App.terrain.gridLines) {
      App.terrain.gridLines.visible = false;
    }
    if (App.terrain.mesh) {
      App.terrain.mesh.material.opacity = 0;
    }

    let progress = 0;
    const scanInterval = setInterval(() => {
      progress += 0.02;
      if (App.terrain.mesh) {
        App.terrain.mesh.material.opacity = Math.min(0.75, progress * 0.75);
      }

      if (progress >= 0.3 && App.terrain.gridLines) {
        App.terrain.gridLines.visible = true;
      }

      if (progress >= 1) {
        clearInterval(scanInterval);
        badge.classList.add('detected');
        scanText.textContent = 'Green detekterad ✓';
        slopeHud.classList.remove('hidden');

        // Transition to place hole mode
        setTimeout(() => {
          App.state = State.PLACE_HOLE;
          updateModeIndicator();
        }, 800);
      }
    }, 50);
  }

  // ============ 3D ENTITIES ============
  function createHoleMarker(position) {
    if (App.holeMarker) {
      App.scene.remove(App.holeMarker);
    }

    const group = new THREE.Group();

    // Hole (dark circle)
    const holeGeom = new THREE.CircleGeometry(0.054, 32);
    const holeMat = new THREE.MeshStandardMaterial({
      color: 0x0A0A0A,
      roughness: 1,
    });
    const hole = new THREE.Mesh(holeGeom, holeMat);
    hole.rotation.x = -Math.PI / 2;
    hole.position.y = 0.002;
    group.add(hole);

    // Flag pole
    const poleGeom = new THREE.CylinderGeometry(0.008, 0.008, 0.8, 8);
    const poleMat = new THREE.MeshStandardMaterial({ color: 0xCCCCCC, metalness: 0.8 });
    const pole = new THREE.Mesh(poleGeom, poleMat);
    pole.position.y = 0.4;
    pole.castShadow = true;
    group.add(pole);

    // Flag
    const flagShape = new THREE.Shape();
    flagShape.moveTo(0, 0);
    flagShape.lineTo(0.15, 0.05);
    flagShape.lineTo(0, 0.1);
    flagShape.closePath();

    const flagGeom = new THREE.ShapeGeometry(flagShape);
    const flagMat = new THREE.MeshStandardMaterial({
      color: 0xEF4444,
      side: THREE.DoubleSide,
      emissive: 0xEF4444,
      emissiveIntensity: 0.2,
    });
    const flag = new THREE.Mesh(flagGeom, flagMat);
    flag.position.set(0.008, 0.7, 0);
    flag.castShadow = true;
    group.add(flag);

    // Glow ring
    const ringGeom = new THREE.RingGeometry(0.06, 0.08, 32);
    const ringMat = new THREE.MeshBasicMaterial({
      color: 0xFACC15,
      transparent: true,
      opacity: 0.6,
      side: THREE.DoubleSide,
    });
    const ring = new THREE.Mesh(ringGeom, ringMat);
    ring.rotation.x = -Math.PI / 2;
    ring.position.y = 0.003;
    group.add(ring);

    group.position.copy(position);
    App.holeMarker = group;
    App.holePosition = position.clone();
    App.scene.add(group);
  }

  function createBallMesh(position) {
    if (App.ballMesh) {
      App.scene.remove(App.ballMesh);
    }

    const group = new THREE.Group();

    // Ball
    const ballGeom = new THREE.SphereGeometry(0.02135, 32, 24);
    const ballMat = new THREE.MeshStandardMaterial({
      color: 0xF5F5F0,
      roughness: 0.35,
      metalness: 0.0,
    });
    const ball = new THREE.Mesh(ballGeom, ballMat);
    ball.castShadow = true;
    ball.position.y = 0.02135;
    group.add(ball);

    // Shadow blob
    const shadowGeom = new THREE.CircleGeometry(0.025, 16);
    const shadowMat = new THREE.MeshBasicMaterial({
      color: 0x000000,
      transparent: true,
      opacity: 0.3,
    });
    const shadow = new THREE.Mesh(shadowGeom, shadowMat);
    shadow.rotation.x = -Math.PI / 2;
    shadow.position.y = 0.001;
    group.add(shadow);

    group.position.copy(position);
    App.ballMesh = group;
    App.ballPosition = position.clone();
    App.scene.add(group);
  }

  function createTrailLine() {
    if (App.trailLine) {
      App.scene.remove(App.trailLine);
    }

    const material = new THREE.LineBasicMaterial({
      color: 0xFACC15,
      transparent: true,
      opacity: 0.7,
      linewidth: 2,
    });

    const geometry = new THREE.BufferGeometry();
    App.trailLine = new THREE.Line(geometry, material);
    App.scene.add(App.trailLine);
  }

  function updateTrailLine(points) {
    if (!App.trailLine || points.length < 2) return;

    const trailPoints = points.map(p =>
      new THREE.Vector3(p.x, p.y + 0.01, p.z)
    );

    App.trailLine.geometry.dispose();
    App.trailLine.geometry = new THREE.BufferGeometry().setFromPoints(trailPoints);
  }

  function createBreakCurve(trailPoints) {
    if (App.breakCurveLine) {
      App.scene.remove(App.breakCurveLine);
    }

    if (trailPoints.length < 3) return;

    // Smooth the trail using CatmullRom spline
    const curvePoints = trailPoints.filter((_, i) => i % 3 === 0).map(p =>
      new THREE.Vector3(p.x, p.y + 0.015, p.z)
    );

    if (curvePoints.length < 2) return;

    const curve = new THREE.CatmullRomCurve3(curvePoints);
    const smoothPoints = curve.getPoints(100);

    // Create tubes/dashed line for break curve
    const geometry = new THREE.BufferGeometry().setFromPoints(smoothPoints);
    const material = new THREE.LineDashedMaterial({
      color: 0xFACC15,
      dashSize: 0.08,
      gapSize: 0.04,
      transparent: true,
      opacity: 0.9,
      linewidth: 2,
    });

    App.breakCurveLine = new THREE.Line(geometry, material);
    App.breakCurveLine.computeLineDistances();
    App.scene.add(App.breakCurveLine);
  }

  // ============ INTERACTION ============
  function onCanvasClick(event) {
    event.preventDefault();

    const rect = App.renderer.domElement.getBoundingClientRect();
    // Lösning för mobila touchskärmar: använd changedTouches vid 'touchend'
    let clientX, clientY;
    if (event.changedTouches && event.changedTouches.length > 0) {
      clientX = event.changedTouches[0].clientX;
      clientY = event.changedTouches[0].clientY;
    } else if (event.touches && event.touches.length > 0) {
      clientX = event.touches[0].clientX;
      clientY = event.touches[0].clientY;
    } else {
      clientX = event.clientX;
      clientY = event.clientY;
    }

    App.mouse.x = ((clientX - rect.left) / rect.width) * 2 - 1;
    App.mouse.y = -((clientY - rect.top) / rect.height) * 2 + 1;

    App.raycaster.setFromCamera(App.mouse, App.camera);

    if (!App.terrain || !App.terrain.mesh) return;

    const intersects = App.raycaster.intersectObject(App.terrain.mesh);
    if (intersects.length === 0) return;

    const point = intersects[0].point;
    const height = App.terrain.getHeightAt(point.x, point.z);
    point.y = height;

    if (App.state === State.PLACE_HOLE) {
      createHoleMarker(point);
      App.state = State.PLACE_BALL;
      updateModeIndicator();

    } else if (App.state === State.PLACE_BALL) {
      createBallMesh(point);
      App.state = State.READY;
      updateModeIndicator();
      showRollButton(true);
      showResetButton(true);
      updateDistanceDisplay();

    } else if (App.state === State.READY) {
      // Tap again to reposition ball
      createBallMesh(point);
      updateDistanceDisplay();
    }
  }

  function onRollClick() {
    if (App.state !== State.READY || !App.ballPosition || !App.holePosition) return;

    App.state = State.ROLLING;
    updateModeIndicator();
    showRollButton(false);
    hideResultsPanel();

    // Init physics
    App.physics.setStimpmeter(App.settings.stimp);
    App.physics.initRoll(App.ballPosition, App.holePosition);

    // Create trail
    createTrailLine();
  }

  function onRollAgain() {
    hideResultsPanel();
    if (App.ballPosition && App.holePosition) {
      // Reset ball to original position
      createBallMesh(App.ballPosition);
      App.state = State.READY;
      updateModeIndicator();
      showRollButton(true);
    }
  }

  function onNewScan() {
    hideResultsPanel();
    resetAll();
  }

  function resetAll() {
    // Remove entities
    if (App.holeMarker) { App.scene.remove(App.holeMarker); App.holeMarker = null; }
    if (App.ballMesh) { App.scene.remove(App.ballMesh); App.ballMesh = null; }
    if (App.trailLine) { App.scene.remove(App.trailLine); App.trailLine = null; }
    if (App.breakCurveLine) { App.scene.remove(App.breakCurveLine); App.breakCurveLine = null; }

    App.holePosition = null;
    App.ballPosition = null;
    App.physics.reset();

    App.state = State.PLACE_HOLE;
    updateModeIndicator();
    showRollButton(false);
    showResetButton(false);
    hideDistanceDisplay();
    hideResultsPanel();
  }

  // ============ UI UPDATES ============
  function updateModeIndicator() {
    const el = document.getElementById('mode-text');
    switch (App.state) {
      case State.SCANNING:
        el.textContent = 'Scanning pågår...';
        break;
      case State.PLACE_HOLE:
        el.textContent = 'Tryck för att placera hål ⛳';
        break;
      case State.PLACE_BALL:
        el.textContent = 'Tryck för att placera boll 🏌️';
        break;
      case State.READY:
        el.textContent = 'Redo att rulla 🎯';
        break;
      case State.ROLLING:
        el.textContent = 'Bollen rullar...';
        break;
      case State.RESULT:
        el.textContent = 'Resultat';
        break;
    }
  }

  function showRollButton(show) {
    document.getElementById('btn-roll').classList.toggle('hidden', !show);
  }

  function showResetButton(show) {
    document.getElementById('btn-reset').classList.toggle('hidden', !show);
  }

  function updateDistanceDisplay() {
    if (!App.ballPosition || !App.holePosition) return;
    const dist = App.ballPosition.distanceTo(App.holePosition);
    const el = document.getElementById('distance-value');
    const container = document.getElementById('distance-display');

    if (App.settings.unit === 'metric') {
      el.textContent = `${dist.toFixed(1)} m`;
    } else {
      el.textContent = `${(dist * 1.0936).toFixed(1)} yd`;
    }
    container.classList.remove('hidden');
  }

  function hideDistanceDisplay() {
    document.getElementById('distance-display').classList.add('hidden');
  }

  function updateSlopeHUD() {
    if (App.state === State.SPLASH) return;

    // Get slope at center of view / cursor
    const centerX = 0;
    const centerZ = 0;

    App.raycaster.setFromCamera(new THREE.Vector2(0, 0), App.camera);
    if (App.terrain && App.terrain.mesh) {
      const intersects = App.raycaster.intersectObject(App.terrain.mesh);
      if (intersects.length > 0) {
        const p = intersects[0].point;
        const slope = App.terrain.getSlopeAt(p.x, p.z);

        document.getElementById('slope-degrees').textContent = `${slope.degrees.toFixed(1)}°`;
        document.getElementById('slope-percent').textContent = `${slope.percent.toFixed(1)}%`;
        document.getElementById('slope-direction').textContent = slope.direction;

        // Color the degree value based on slope
        const degEl = document.getElementById('slope-degrees');
        if (slope.degrees < 0.8) {
          degEl.style.color = '#22C55E';
        } else if (slope.degrees < 2.5) {
          degEl.style.color = '#FACC15';
        } else {
          degEl.style.color = '#EF4444';
        }
      }
    }
  }

  function showResultsPanel(result) {
    const panel = document.getElementById('results-panel');

    // Distance
    let distText = `${result.distance.toFixed(1)} m`;
    if (App.settings.unit === 'imperial') {
      distText = `${(result.distance * 1.0936).toFixed(1)} yd`;
    }
    document.getElementById('result-distance').textContent = distText;
    
    document.getElementById('result-confidence').textContent = 
      App.dataSource === 'lantmateriet' ? '14 milj. punkter LiDAR' : 'Procedurellt';

    // Break
    let breakText = `${result.breakAmount.toFixed(1)} cm`;
    if (App.settings.breakUnit === 'inch') {
      breakText = `${(result.breakAmount * 0.3937).toFixed(1)}"`;
    }
    document.getElementById('result-break').textContent = breakText;
    document.getElementById('result-break-dir').textContent = result.breakDirection;

    // Slope
    document.getElementById('result-slope').textContent = `${result.slopePercent.toFixed(1)}%`;
    document.getElementById('result-slope-type').textContent = result.slopeType;

    // Stimp
    document.getElementById('result-stimp').textContent = App.settings.stimp.toFixed(1);

    // Speed recommendation
    document.getElementById('speed-text').textContent = result.speedRecommendation;
    document.getElementById('speed-marker').style.left = `${result.speedPercent}%`;

    // Color break value
    const breakEl = document.getElementById('result-break');
    if (result.breakAmount < 2) {
      breakEl.style.color = '#22C55E';
    } else if (result.breakAmount < 8) {
      breakEl.style.color = '#FACC15';
    } else {
      breakEl.style.color = '#EF4444';
    }

    panel.classList.remove('hidden');
  }

  function hideResultsPanel() {
    document.getElementById('results-panel').classList.add('hidden');
  }

  // ============ CAMERA CONTROLS ============
  let isDragging = false;
  let lastMouseX = 0;
  let lastMouseY = 0;
  let cameraTheta = 0;       // horizontal angle
  let cameraPhi = 0.75;      // vertical angle (radians from top)
  let cameraRadius = 10;
  let cameraTarget = new THREE.Vector3(0, 0, -1);

  function updateCameraOrbit() {
    const x = cameraRadius * Math.sin(cameraPhi) * Math.sin(cameraTheta);
    const y = cameraRadius * Math.cos(cameraPhi);
    const z = cameraRadius * Math.sin(cameraPhi) * Math.cos(cameraTheta);

    App.camera.position.set(
      cameraTarget.x + x,
      cameraTarget.y + y,
      cameraTarget.z + z
    );
    App.camera.lookAt(cameraTarget);
  }

  function onPointerDown(e) {
    // Don't start orbit if clicking UI elements
    if (e.target !== App.renderer.domElement) return;

    isDragging = true;
    const clientX = e.touches ? e.touches[0].clientX : e.clientX;
    const clientY = e.touches ? e.touches[0].clientY : e.clientY;
    lastMouseX = clientX;
    lastMouseY = clientY;
  }

  function onPointerMove(e) {
    if (!isDragging) return;

    const clientX = e.touches ? e.touches[0].clientX : e.clientX;
    const clientY = e.touches ? e.touches[0].clientY : e.clientY;

    const deltaX = clientX - lastMouseX;
    const deltaY = clientY - lastMouseY;

    cameraTheta -= deltaX * 0.005;
    cameraPhi = Math.max(0.2, Math.min(1.4, cameraPhi - deltaY * 0.005));

    lastMouseX = clientX;
    lastMouseY = clientY;

    updateCameraOrbit();
  }

  function onPointerUp(e) {
    if (!isDragging) {
      // This was a click/tap, not a drag
      onCanvasClick(e);
    }
    isDragging = false;
  }

  function onWheel(e) {
    cameraRadius = Math.max(4, Math.min(20, cameraRadius + e.deltaY * 0.01));
    updateCameraOrbit();
  }

  // Distinguish click from drag
  let pointerDownTime = 0;
  let pointerDownPos = { x: 0, y: 0 };

  function onPointerDownTrack(e) {
    pointerDownTime = Date.now();
    const clientX = e.touches ? e.touches[0].clientX : e.clientX;
    const clientY = e.touches ? e.touches[0].clientY : e.clientY;
    pointerDownPos = { x: clientX, y: clientY };
    isDragging = false;
    lastMouseX = clientX;
    lastMouseY = clientY;
  }

  function onPointerMoveTrack(e) {
    const clientX = e.touches ? e.touches[0].clientX : e.clientX;
    const clientY = e.touches ? e.touches[0].clientY : e.clientY;
    const dx = clientX - pointerDownPos.x;
    const dy = clientY - pointerDownPos.y;
    const dist = Math.sqrt(dx * dx + dy * dy);

    if (dist > 5 && pointerDownTime > 0) {
      isDragging = true;
    }

    if (isDragging) {
      const deltaX = clientX - lastMouseX;
      const deltaY = clientY - lastMouseY;

      cameraTheta -= deltaX * 0.005;
      cameraPhi = Math.max(0.2, Math.min(1.4, cameraPhi - deltaY * 0.005));

      updateCameraOrbit();
    }

    lastMouseX = clientX;
    lastMouseY = clientY;
  }

  function onPointerUpTrack(e) {
    const elapsed = Date.now() - pointerDownTime;
    if (!isDragging && elapsed < 300) {
      // This was a tap/click
      onCanvasClick(e);
    }
    isDragging = false;
    pointerDownTime = 0;
  }

  // ============ ANIMATION LOOP ============
  let flagWaveTime = 0;
  let ballRollRotation = 0;

  function animate() {
    requestAnimationFrame(animate);

    const delta = App.clock.getDelta();
    flagWaveTime += delta;

    // Animate flag waving
    if (App.holeMarker) {
      const flag = App.holeMarker.children[2]; // Flag mesh
      if (flag) {
        flag.rotation.y = Math.sin(flagWaveTime * 2) * 0.15;
      }
      // Pulse glow ring
      const ring = App.holeMarker.children[3];
      if (ring) {
        ring.material.opacity = 0.3 + Math.sin(flagWaveTime * 3) * 0.3;
        ring.scale.set(
          1 + Math.sin(flagWaveTime * 2) * 0.1,
          1 + Math.sin(flagWaveTime * 2) * 0.1,
          1
        );
      }
    }

    // Update ball physics
    if (App.state === State.ROLLING && App.physics.isRolling) {
      const result = App.physics.update(delta);
      if (result) {
        // Update ball mesh position
        App.ballMesh.position.copy(result.position);
        App.ballMesh.position.y = result.position.y - App.physics.radius;

        // Rotate ball (rolling effect)
        const speed = result.velocity.length();
        if (speed > 0.01) {
          const rotAxis = new THREE.Vector3(-result.velocity.z, 0, result.velocity.x).normalize();
          const rotAngle = speed * delta / App.physics.radius;
          App.ballMesh.children[0].rotateOnWorldAxis(rotAxis, rotAngle);
        }

        // Update trail
        updateTrailLine(App.physics.getTrailPoints());
      }

      // Ball stopped
      if (!App.physics.isRolling) {
        App.state = State.RESULT;
        updateModeIndicator();

        // Create break curve
        createBreakCurve(App.physics.getTrailPoints());

        // Calculate and show results
        const breakResult = App.physics.getBreakResult(App.holePosition);
        if (breakResult) {
          showResultsPanel(breakResult);
        }

        showRollButton(false);
        showResetButton(true);

        // Fade trail after 3 seconds
        setTimeout(() => {
          if (App.trailLine) {
            let fadeOp = 0.7;
            const fadeInterval = setInterval(() => {
              fadeOp -= 0.02;
              if (fadeOp <= 0) {
                clearInterval(fadeInterval);
                if (App.trailLine) {
                  App.scene.remove(App.trailLine);
                  App.trailLine = null;
                }
              } else {
                App.trailLine.material.opacity = fadeOp;
              }
            }, 50);
          }
        }, 3000);
      }
    }

    // Update slope HUD periodically
    updateSlopeHUD();

    // Render
    if (App.renderer) {
      App.renderer.render(App.scene, App.camera);
    }
  }

  // ============ EVENT LISTENERS ============
  function setupEventListeners() {
    // Splash → Camera
    document.getElementById('btn-start').addEventListener('click', () => {
      document.getElementById('splash-screen').classList.remove('active');
      document.getElementById('camera-screen').classList.add('active');
      initScene();
      updateCameraOrbit();
    });

    // Canvas interactions (after scene init)
    const canvas = document.getElementById('ar-canvas');
    canvas.addEventListener('mousedown', onPointerDownTrack);
    canvas.addEventListener('mousemove', onPointerMoveTrack);
    canvas.addEventListener('mouseup', onPointerUpTrack);
    canvas.addEventListener('touchstart', (e) => { e.preventDefault(); onPointerDownTrack(e); }, { passive: false });
    canvas.addEventListener('touchmove', (e) => { e.preventDefault(); onPointerMoveTrack(e); }, { passive: false });
    canvas.addEventListener('touchend', (e) => { e.preventDefault(); onPointerUpTrack(e); }, { passive: false });
    canvas.addEventListener('wheel', onWheel, { passive: true });

    // Roll button
    document.getElementById('btn-roll').addEventListener('click', (e) => {
      e.stopPropagation();
      onRollClick();
    });

    // Reset
    document.getElementById('btn-reset').addEventListener('click', (e) => {
      e.stopPropagation();
      resetAll();
    });

    // Results buttons
    document.getElementById('btn-roll-again').addEventListener('click', onRollAgain);
    document.getElementById('btn-new-scan').addEventListener('click', onNewScan);

    // Settings
    document.getElementById('btn-settings').addEventListener('click', (e) => {
      e.stopPropagation();
      document.getElementById('settings-panel').classList.remove('hidden');
    });

    document.getElementById('btn-close-settings').addEventListener('click', () => {
      document.getElementById('settings-panel').classList.add('hidden');
    });

    // Stimp slider
    const stimpSlider = document.getElementById('stimp-slider');
    const stimpValue = document.getElementById('stimp-value');
    stimpSlider.addEventListener('input', () => {
      const val = parseFloat(stimpSlider.value);
      App.settings.stimp = val;
      stimpValue.textContent = val.toFixed(1);
      if (App.physics) {
        App.physics.setStimpmeter(val);
      }
    });

    // Toggle buttons
    document.querySelectorAll('.toggle-group').forEach(group => {
      group.querySelectorAll('.toggle-btn').forEach(btn => {
        btn.addEventListener('click', () => {
          group.querySelectorAll('.toggle-btn').forEach(b => b.classList.remove('active'));
          btn.classList.add('active');

          // Update settings
          if (btn.dataset.unit) App.settings.unit = btn.dataset.unit;
          if (btn.dataset.break) App.settings.breakUnit = btn.dataset.break;
          if (btn.dataset.balls) App.settings.numBalls = parseInt(btn.dataset.balls);

          // Refresh distance display if visible
          if (App.ballPosition && App.holePosition) {
            updateDistanceDisplay();
          }
        });
      });
    });

    // Resize
    window.addEventListener('resize', () => {
      if (!App.renderer) return;
      App.camera.aspect = window.innerWidth / window.innerHeight;
      App.camera.updateProjectionMatrix();
      App.renderer.setSize(window.innerWidth, window.innerHeight);
    });
  }

  // ============ START ============
  document.addEventListener('DOMContentLoaded', init);
})();
