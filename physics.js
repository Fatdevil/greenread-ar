/* ============================================
   GreenRead AR — Ball Physics Engine
   Simulates ball roll on green terrain mesh
   Mass: 0.046 kg (standard golf ball)
   Friction: variable per Stimpmeter (7–13)
   ============================================ */

class BallPhysics {
  constructor(terrain) {
    this.terrain = terrain;
    this.mass = 0.046; // kg
    this.radius = 0.02135; // meters (standard golf ball radius)
    this.gravity = 9.81;
    this.stimp = 10.0;
    this.minSpeed = 0.02; // m/s — stop threshold

    // Friction coefficient derived from Stimpmeter
    // Stimp = distance ball rolls on flat surface from standardized ramp
    // Higher stimp = less friction = faster green
    this.updateFriction();

    // State
    this.position = new THREE.Vector3();
    this.velocity = new THREE.Vector3();
    this.isRolling = false;
    this.trail = [];  // position history for break curve
    this.maxTrailLength = 500;

    // Results
    this.totalBreak = 0;
    this.totalDistance = 0;
    this.startPosition = new THREE.Vector3();
  }

  setStimpmeter(value) {
    this.stimp = Math.max(7, Math.min(13, value));
    this.updateFriction();
  }

  updateFriction() {
    // Approximate friction coefficient from Stimpmeter
    // Higher stimp → lower friction
    // mu ≈ 1 / (stimp * 0.4) — calibrated for realistic roll
    this.frictionCoeff = 1.0 / (this.stimp * 0.38);
  }

  initRoll(startPos, holePos) {
    this.position.copy(startPos);
    this.startPosition.copy(startPos);
    this.trail = [startPos.clone()];
    this.isRolling = true;

    // Calculate initial velocity towards hole
    const dir = new THREE.Vector3().subVectors(holePos, startPos);
    const distance = dir.length();
    dir.normalize();

    // Calculate needed initial speed considering slope and friction
    const avgSlope = this.terrain.getSlopeAt(
      (startPos.x + holePos.x) / 2,
      (startPos.z + holePos.z) / 2
    );

    // Base speed from distance — tuned for realism
    let speed = distance * 1.4 + 0.5;

    // Adjust for average slope along the putt line
    const slopeComponent = avgSlope.normal.dot(dir);
    if (slopeComponent < 0) {
      // Uphill — need more speed
      speed *= 1 + Math.abs(slopeComponent) * 2.5;
    } else {
      // Downhill — need less speed
      speed *= 1 - slopeComponent * 1.2;
    }

    // Adjust for green speed
    speed *= (10 / this.stimp);

    // Set initial velocity — slightly off-center to create realistic break
    this.velocity.set(
      dir.x * speed,
      0,
      dir.z * speed
    );

    this.totalBreak = 0;
    this.totalDistance = 0;
  }

  update(deltaTime) {
    if (!this.isRolling) return null;

    const dt = Math.min(deltaTime, 0.016); // Cap at ~60fps equivalent
    const substeps = 4;
    const subDt = dt / substeps;

    for (let s = 0; s < substeps; s++) {
      // Get terrain info at current position
      const height = this.terrain.getHeightAt(this.position.x, this.position.z);
      const slope = this.terrain.getSlopeAt(this.position.x, this.position.z);

      // Gravity component along slope (drives ball downhill)
      const gravityForce = new THREE.Vector3(
        slope.normal.x * this.gravity,
        0,
        slope.normal.z * this.gravity
      );

      // Only apply the horizontal component of gravity on the slope
      const slopeAccel = new THREE.Vector3(
        -slope.normal.x * this.gravity * (1 - slope.normal.y),
        0,
        -slope.normal.z * this.gravity * (1 - slope.normal.y)
      );

      // Rolling friction (opposes velocity direction)
      const speed = this.velocity.length();
      const frictionForce = new THREE.Vector3();
      if (speed > 0.001) {
        frictionForce.copy(this.velocity).normalize().multiplyScalar(
          -this.frictionCoeff * this.gravity
        );
      }

      // Gravity along slope surface — this creates the break
      const slopeGravity = new THREE.Vector3(
        slope.fallDir.x * Math.sin(slope.degrees * Math.PI / 180) * this.gravity,
        0,
        slope.fallDir.z * Math.sin(slope.degrees * Math.PI / 180) * this.gravity
      );

      // Total acceleration
      const accel = new THREE.Vector3()
        .add(slopeGravity)
        .add(frictionForce);

      // Verlet integration
      this.velocity.add(accel.multiplyScalar(subDt));
      this.position.add(this.velocity.clone().multiplyScalar(subDt));

      // Snap to terrain surface
      this.position.y = this.terrain.getHeightAt(this.position.x, this.position.z) + this.radius;

      // Track break (lateral displacement from straight line)
      this.totalDistance += speed * subDt;

      // Check bounds
      if (Math.abs(this.position.x) > this.terrain.width / 2 ||
          Math.abs(this.position.z) > this.terrain.depth / 2) {
        this.isRolling = false;
        break;
      }

      // Check stop condition
      if (speed < this.minSpeed && this.totalDistance > 0.1) {
        this.isRolling = false;
        break;
      }
    }

    // Record trail
    this.trail.push(this.position.clone());
    if (this.trail.length > this.maxTrailLength) {
      this.trail.shift();
    }

    return {
      position: this.position.clone(),
      velocity: this.velocity.clone(),
      isRolling: this.isRolling,
      speed: this.velocity.length()
    };
  }

  getBreakResult(holePos) {
    if (this.trail.length < 2) return null;

    // Straight line from start to hole
    const startToHole = new THREE.Vector3().subVectors(holePos, this.startPosition);
    const lineDir = startToHole.clone().normalize();
    const distance = startToHole.length();

    // Find max lateral displacement (break amount)
    let maxBreak = 0;
    let breakDirection = 'Rak';
    
    for (const point of this.trail) {
      const startToPoint = new THREE.Vector3().subVectors(point, this.startPosition);
      const projection = lineDir.clone().multiplyScalar(startToPoint.dot(lineDir));
      const lateral = new THREE.Vector3().subVectors(startToPoint, projection);
      const lateralDist = lateral.length();

      if (lateralDist > Math.abs(maxBreak)) {
        // Determine left or right
        const cross = new THREE.Vector3().crossVectors(lineDir, lateral);
        maxBreak = lateralDist * (cross.y > 0 ? 1 : -1);
      }
    }

    // Calculate slope along putt line
    const midPoint = new THREE.Vector3().addVectors(this.startPosition, holePos).multiplyScalar(0.5);
    const slope = this.terrain.getSlopeAt(midPoint.x, midPoint.z);

    // Determine uphill/downhill
    const heightStart = this.terrain.getHeightAt(this.startPosition.x, this.startPosition.z);
    const heightHole = this.terrain.getHeightAt(holePos.x, holePos.z);
    const elevationChange = heightHole - heightStart;
    const slopeType = elevationChange > 0.01 ? 'Uppförsbacke' :
                      elevationChange < -0.01 ? 'Nedförsbacke' : 'Plant';

    // Determine break direction
    if (Math.abs(maxBreak) < 0.005) {
      breakDirection = 'Rak putt';
    } else {
      breakDirection = maxBreak > 0 ? 'Vänster' : 'Höger';
    }

    // Speed recommendation
    let speedRec = 'Normalt slag';
    let speedPercent = 50;
    if (slopeType === 'Uppförsbacke') {
      const grade = Math.abs(elevationChange / distance) * 100;
      speedPercent = 50 + grade * 5;
      if (grade > 3) {
        speedRec = `Hårt — ${Math.round(grade)}% uppförsbacke`;
      } else {
        speedRec = `Normalt-Hårt — ${Math.round(grade)}% uppför`;
      }
    } else if (slopeType === 'Nedförsbacke') {
      const grade = Math.abs(elevationChange / distance) * 100;
      speedPercent = 50 - grade * 5;
      if (grade > 3) {
        speedRec = `Mjukt — ${Math.round(grade)}% nedförsbacke`;
      } else {
        speedRec = `Mjukt-Normalt — ${Math.round(grade)}% nedför`;
      }
    }

    speedPercent = Math.max(5, Math.min(95, speedPercent));

    return {
      distance: distance,
      breakAmount: Math.abs(maxBreak) * 100, // convert to cm
      breakDirection: breakDirection,
      slopePercent: slope.percent,
      slopeType: slopeType,
      speedRecommendation: speedRec,
      speedPercent: speedPercent,
      elevationChange: elevationChange
    };
  }

  getTrailPoints() {
    return this.trail;
  }

  reset() {
    this.isRolling = false;
    this.position.set(0, 0, 0);
    this.velocity.set(0, 0, 0);
    this.trail = [];
    this.totalBreak = 0;
    this.totalDistance = 0;
  }
}
