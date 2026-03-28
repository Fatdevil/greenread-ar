/* ============================================
   GreenRead AR — Green Terrain Generator
   Procedural putting green with realistic slopes
   ============================================ */

class GreenTerrain {
  constructor(scene) {
    this.scene = scene;
    this.width = 12;       // meters
    this.depth = 14;       // meters
    this.resolution = 60;  // subdivisions per axis — 20cm cells
    this.mesh = null;
    this.gridLines = null;
    this.slopeData = [];   // per-vertex slope info
    this.heightMap = [];
  }

  generate() {
    this.generateHeightMap();
    this.createGreenMesh();
    this.createSlopeGrid();
    return this;
  }

  generateHeightMap() {
    // Build a realistic undulating green with subtle breaks
    const w = this.resolution + 1;
    const d = this.resolution + 1;
    this.heightMap = [];

    for (let iz = 0; iz < d; iz++) {
      this.heightMap[iz] = [];
      for (let ix = 0; ix < w; ix++) {
        const nx = ix / this.resolution;
        const nz = iz / this.resolution;

        // Base slope: gentle back-to-front tilt
        let h = (1 - nz) * 0.35;

        // Undulation 1: broad left-right ridge
        h += Math.sin(nx * Math.PI * 1.3) * 0.12;

        // Undulation 2: subtle cross-break
        h += Math.sin(nz * Math.PI * 0.8 + nx * 1.5) * 0.08;

        // Undulation 3: localized mound near center
        const cx = nx - 0.45;
        const cz = nz - 0.55;
        h += Math.exp(-(cx * cx + cz * cz) * 12) * 0.15;

        // Undulation 4: subtle depression (collection area)
        const dx = nx - 0.7;
        const dz = nz - 0.3;
        h -= Math.exp(-(dx * dx + dz * dz) * 18) * 0.1;

        this.heightMap[iz][ix] = h;
      }
    }
  }

  getHeightAt(worldX, worldZ) {
    // Convert world coordinates to grid coordinates
    const nx = (worldX + this.width / 2) / this.width;
    const nz = (worldZ + this.depth / 2) / this.depth;

    if (nx < 0 || nx > 1 || nz < 0 || nz > 1) return 0;

    const gx = nx * this.resolution;
    const gz = nz * this.resolution;
    const ix = Math.floor(gx);
    const iz = Math.floor(gz);
    const fx = gx - ix;
    const fz = gz - iz;

    const ix1 = Math.min(ix + 1, this.resolution);
    const iz1 = Math.min(iz + 1, this.resolution);

    // Bilinear interpolation
    const h00 = this.heightMap[iz][ix];
    const h10 = this.heightMap[iz][ix1];
    const h01 = this.heightMap[iz1][ix];
    const h11 = this.heightMap[iz1][ix1];

    return h00 * (1 - fx) * (1 - fz) +
           h10 * fx * (1 - fz) +
           h01 * (1 - fx) * fz +
           h11 * fx * fz;
  }

  getNormalAt(worldX, worldZ) {
    const eps = 0.05;
    const hL = this.getHeightAt(worldX - eps, worldZ);
    const hR = this.getHeightAt(worldX + eps, worldZ);
    const hD = this.getHeightAt(worldX, worldZ - eps);
    const hU = this.getHeightAt(worldX, worldZ + eps);

    const normal = new THREE.Vector3(
      (hL - hR) / (2 * eps),
      1,
      (hD - hU) / (2 * eps)
    ).normalize();

    return normal;
  }

  getSlopeAt(worldX, worldZ) {
    const normal = this.getNormalAt(worldX, worldZ);
    const up = new THREE.Vector3(0, 1, 0);
    const angle = Math.acos(Math.min(1, normal.dot(up)));
    const degrees = angle * (180 / Math.PI);
    const percent = Math.tan(angle) * 100;

    // Fall direction
    const fallDir = new THREE.Vector3(normal.x, 0, normal.z).normalize();
    const compassAngle = Math.atan2(fallDir.x, fallDir.z) * (180 / Math.PI);

    let direction = '—';
    if (degrees > 0.3) {
      if (compassAngle > -22.5 && compassAngle <= 22.5) direction = '↑ N';
      else if (compassAngle > 22.5 && compassAngle <= 67.5) direction = '↗ NE';
      else if (compassAngle > 67.5 && compassAngle <= 112.5) direction = '→ E';
      else if (compassAngle > 112.5 && compassAngle <= 157.5) direction = '↘ SE';
      else if (compassAngle > 157.5 || compassAngle <= -157.5) direction = '↓ S';
      else if (compassAngle > -157.5 && compassAngle <= -112.5) direction = '↙ SW';
      else if (compassAngle > -112.5 && compassAngle <= -67.5) direction = '← W';
      else if (compassAngle > -67.5 && compassAngle <= -22.5) direction = '↖ NW';
    }

    return { degrees, percent, direction, fallDir, normal };
  }

  createGreenMesh() {
    const geometry = new THREE.PlaneGeometry(
      this.width, this.depth,
      this.resolution, this.resolution
    );

    const positions = geometry.attributes.position;
    const colors = new Float32Array(positions.count * 3);

    for (let i = 0; i < positions.count; i++) {
      const x = positions.getX(i);
      const z = positions.getY(i); // PlaneGeometry Y = world Z before rotation
      const ix = Math.round((x + this.width / 2) / this.width * this.resolution);
      const iz = Math.round((z + this.depth / 2) / this.depth * this.resolution);

      const ixC = Math.max(0, Math.min(this.resolution, ix));
      const izC = Math.max(0, Math.min(this.resolution, iz));

      const h = this.heightMap[izC][ixC];
      positions.setZ(i, h);

      // Color based on slope
      const worldX = x;
      const worldZ = z;
      const slope = this.getSlopeAt(worldX, worldZ);

      let r, g, b;
      if (slope.degrees < 0.8) {
        // Flat — green
        r = 0.133; g = 0.773; b = 0.369;
      } else if (slope.degrees < 2.5) {
        // Moderate slope — blend
        const t = (slope.degrees - 0.8) / 1.7;
        // Check if uphill or downhill based on z-component of fall direction
        if (slope.fallDir.z > 0.1) {
          // Downhill (towards camera) — blue
          r = 0.133 + t * (0.231 - 0.133);
          g = 0.773 + t * (0.510 - 0.773);
          b = 0.369 + t * (0.965 - 0.369);
        } else {
          // Uphill — red/orange
          r = 0.133 + t * (0.937 - 0.133);
          g = 0.773 + t * (0.267 - 0.773);
          b = 0.369 + t * (0.267 - 0.369);
        }
      } else {
        // Steep slope — saturated
        if (slope.fallDir.z > 0.1) {
          r = 0.231; g = 0.510; b = 0.965; // Blue
        } else {
          r = 0.937; g = 0.267; b = 0.267; // Red
        }
      }

      colors[i * 3] = r;
      colors[i * 3 + 1] = g;
      colors[i * 3 + 2] = b;
    }

    geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
    geometry.computeVertexNormals();

    // Rotate to horizontal (PlaneGeometry faces Z by default)
    geometry.rotateX(-Math.PI / 2);

    const material = new THREE.MeshStandardMaterial({
      vertexColors: true,
      transparent: true,
      opacity: 0.75,
      roughness: 0.9,
      metalness: 0.0,
      side: THREE.DoubleSide,
      wireframe: false,
    });

    this.mesh = new THREE.Mesh(geometry, material);
    this.mesh.receiveShadow = true;
    this.scene.add(this.mesh);
  }

  createSlopeGrid() {
    const gridGroup = new THREE.Group();
    const cellSize = this.width / this.resolution;

    // Create grid lines with slope-dependent color
    const material = new THREE.LineBasicMaterial({
      vertexColors: true,
      transparent: true,
      opacity: 0.35,
      linewidth: 1,
    });

    // Horizontal lines
    for (let iz = 0; iz <= this.resolution; iz += 3) {
      const points = [];
      const lineColors = [];

      for (let ix = 0; ix <= this.resolution; ix++) {
        const x = (ix / this.resolution - 0.5) * this.width;
        const z = (iz / this.resolution - 0.5) * this.depth;
        const h = this.getHeightAt(x, z);
        points.push(new THREE.Vector3(x, h + 0.005, z));

        const slope = this.getSlopeAt(x, z);
        const color = this.slopeToColor(slope);
        lineColors.push(color.r, color.g, color.b);
      }

      const geom = new THREE.BufferGeometry().setFromPoints(points);
      geom.setAttribute('color', new THREE.Float32BufferAttribute(lineColors, 3));
      const line = new THREE.Line(geom, material);
      gridGroup.add(line);
    }

    // Vertical lines
    for (let ix = 0; ix <= this.resolution; ix += 3) {
      const points = [];
      const lineColors = [];

      for (let iz = 0; iz <= this.resolution; iz++) {
        const x = (ix / this.resolution - 0.5) * this.width;
        const z = (iz / this.resolution - 0.5) * this.depth;
        const h = this.getHeightAt(x, z);
        points.push(new THREE.Vector3(x, h + 0.005, z));

        const slope = this.getSlopeAt(x, z);
        const color = this.slopeToColor(slope);
        lineColors.push(color.r, color.g, color.b);
      }

      const geom = new THREE.BufferGeometry().setFromPoints(points);
      geom.setAttribute('color', new THREE.Float32BufferAttribute(lineColors, 3));
      const line = new THREE.Line(geom, material);
      gridGroup.add(line);
    }

    this.gridLines = gridGroup;
    this.scene.add(gridGroup);
  }

  slopeToColor(slope) {
    const d = slope.degrees;
    if (d < 0.8) {
      return { r: 0.133, g: 0.773, b: 0.369 }; // Green
    } else if (d < 3.0) {
      const t = (d - 0.8) / 2.2;
      if (slope.fallDir.z > 0.1) {
        // Downhill — to blue
        return {
          r: 0.133 + t * (0.231 - 0.133),
          g: 0.773 + t * (0.510 - 0.773),
          b: 0.369 + t * (0.965 - 0.369)
        };
      } else {
        // Uphill — to red
        return {
          r: 0.133 + t * (0.937 - 0.133),
          g: 0.773 + t * (0.267 - 0.773),
          b: 0.369 + t * (0.267 - 0.369)
        };
      }
    } else {
      if (slope.fallDir.z > 0.1) {
        return { r: 0.231, g: 0.510, b: 0.965 };
      } else {
        return { r: 0.937, g: 0.267, b: 0.267 };
      }
    }
  }
}
