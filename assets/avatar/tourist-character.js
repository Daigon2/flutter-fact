/* =========================================================================
 *  FACT — 3D Tourist Character
 *  ----------------------------------------------------------------------
 *  Self-contained Three.js component. Drop the file into your project and
 *  mount it into any element:
 *
 *      <div id="hero" style="width:280px;height:340px;"></div>
 *      <script src="tourist-character.js"></script>
 *      <script>
 *        const tourist = FactTourist.mount(document.getElementById('hero'), {
 *          background: 'transparent',     // or a hex colour
 *          animation: 'idle',             // 'idle' | 'walk' | 'wave'
 *          autoRotate: false,
 *        });
 *        tourist.play('walk');
 *        tourist.dispose();               // clean up when unmounting
 *      </script>
 *
 *  Vite / React usage:
 *      import { mount } from './tourist-character.js';
 *      useEffect(() => {
 *        const t = mount(ref.current, { animation: 'idle' });
 *        return () => t.dispose();
 *      }, []);
 *
 *  No external assets, no CSS bleed — the canvas is the only thing this
 *  component touches inside the host element.
 * =========================================================================
 */

(function (root) {
  'use strict';

  // ---- Brand palette (matches FACT CI) ---------------------------------
  const PALETTE = {
    skin:       0xf2c69a,
    skinShade:  0xd99e6c,
    shirt:      0xe85a2a, // brand orange
    shirtDark:  0xb8431d,
    pants:      0x2a3242, // brand navy
    pantsDark:  0x171c27,
    shoe:       0xf6efe2, // cream
    shoeAccent: 0xe85a2a,
    cap:        0xd84236, // brand red
    capDark:    0xa1271e,
    backpack:   0x6f4a2a,
    backpackD:  0x4a2f18,
    backpackA:  0xf4b84a, // yellow accent
    camera:     0x1f1f2e,
    cameraLens: 0x0a0a12,
    cameraRing: 0xf4b84a,
    hair:       0x3a2a1e,
    mouth:      0x6b1f15,
  };

  // ---- Shared toon gradient map ---------------------------------------
  function makeToonGradient(THREE) {
    const c = document.createElement('canvas');
    c.width = 4; c.height = 1;
    const ctx = c.getContext('2d');
    ctx.fillStyle = '#555'; ctx.fillRect(0, 0, 1, 1);
    ctx.fillStyle = '#999'; ctx.fillRect(1, 0, 1, 1);
    ctx.fillStyle = '#cfcfcf'; ctx.fillRect(2, 0, 1, 1);
    ctx.fillStyle = '#ffffff'; ctx.fillRect(3, 0, 1, 1);
    const tex = new THREE.CanvasTexture(c);
    tex.minFilter = THREE.NearestFilter;
    tex.magFilter = THREE.NearestFilter;
    tex.generateMipmaps = false;
    return tex;
  }

  // Helpers --------------------------------------------------------------
  function toonMat(THREE, color, gradientMap) {
    return new THREE.MeshToonMaterial({ color, gradientMap });
  }

  // Rounded box geometry (chunky Clash-of-Clans look without external deps)
  function roundedBox(THREE, w, h, d, r, seg) {
    seg = seg || 3;
    const shape = new THREE.Shape();
    const x = -w / 2, y = -h / 2;
    shape.moveTo(x + r, y);
    shape.lineTo(x + w - r, y);
    shape.quadraticCurveTo(x + w, y, x + w, y + r);
    shape.lineTo(x + w, y + h - r);
    shape.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
    shape.lineTo(x + r, y + h);
    shape.quadraticCurveTo(x, y + h, x, y + h - r);
    shape.lineTo(x, y + r);
    shape.quadraticCurveTo(x, y, x + r, y);
    const geom = new THREE.ExtrudeGeometry(shape, {
      depth: d - r * 2,
      bevelEnabled: true,
      bevelSegments: seg,
      steps: 1,
      bevelSize: r,
      bevelThickness: r,
      curveSegments: 8,
    });
    geom.translate(0, 0, -(d - r * 2) / 2);
    geom.computeVertexNormals();
    return geom;
  }

  // ----------------------------------------------------------------------
  //  Build the character — a hierarchy of named groups so we can animate
  //  individual joints (head, shoulders, hips, etc.).
  // ----------------------------------------------------------------------
  function buildCharacter(THREE) {
    const grad = makeToonGradient(THREE);
    const m = (c) => toonMat(THREE, c, grad);

    const root = new THREE.Group();
    root.name = 'tourist';

    // ----- Hips / body anchor -----------------------------------------
    const hips = new THREE.Group();
    hips.position.y = 0.95;
    root.add(hips);

    // ----- Torso (slimmer human shape: wider shoulders, tapered waist) ---
    // Built as a capsule scaled non-uniformly so it has human depth/width ratio
    // (~1.6:1) instead of a square block.
    const torsoGeom = new THREE.CapsuleGeometry(0.26, 0.42, 8, 18);
    torsoGeom.scale(1.05, 1.0, 0.7);
    const torso = new THREE.Mesh(torsoGeom, m(PALETTE.shirt));
    torso.position.y = 0.22;
    torso.castShadow = true;
    hips.add(torso);

    // Slight shoulder yoke — broader at the top to read as shoulders, not a tube
    const shoulderYoke = new THREE.Mesh(
      new THREE.SphereGeometry(0.32, 18, 14, 0, Math.PI * 2, 0, Math.PI / 2.2),
      m(PALETTE.shirt)
    );
    shoulderYoke.position.y = 0.5;
    shoulderYoke.scale.set(1.05, 0.55, 0.72);
    hips.add(shoulderYoke);

    // T-shirt collar
    const collar = new THREE.Mesh(
      new THREE.TorusGeometry(0.13, 0.04, 12, 24),
      m(PALETTE.shirtDark)
    );
    collar.position.set(0, 0.58, 0.06);
    collar.rotation.x = Math.PI / 2;
    collar.scale.set(1, 1, 0.55);
    hips.add(collar);

    // ----- Head pivot --------------------------------------------------
    const head = new THREE.Group();
    head.position.y = 0.78;
    hips.add(head);

    // Face — a slightly squashed sphere with a flat front for the toon look
    const headMesh = new THREE.Mesh(
      new THREE.SphereGeometry(0.36, 24, 20),
      m(PALETTE.skin)
    );
    headMesh.scale.set(1, 0.95, 0.92);
    headMesh.castShadow = true;
    head.add(headMesh);

    // Hair tuft (visible under cap at the back)
    const hair = new THREE.Mesh(
      new THREE.SphereGeometry(0.32, 16, 12, 0, Math.PI * 2, 0, Math.PI / 2),
      m(PALETTE.hair)
    );
    hair.position.set(0, 0.06, -0.04);
    hair.scale.set(1.05, 0.55, 1.05);
    head.add(hair);

    // Eyes
    const eyeMat = m(0x1a1a22);
    const eyeGeom = new THREE.SphereGeometry(0.045, 12, 12);
    const eyeL = new THREE.Mesh(eyeGeom, eyeMat);
    const eyeR = new THREE.Mesh(eyeGeom, eyeMat);
    eyeL.position.set(-0.12, -0.02, 0.31);
    eyeR.position.set( 0.12, -0.02, 0.31);
    eyeL.scale.set(1, 1.2, 0.6);
    eyeR.scale.set(1, 1.2, 0.6);
    head.add(eyeL); head.add(eyeR);

    // Cheek blush (small pink discs)
    const blushMat = m(0xe88c7a);
    const blushGeom = new THREE.CircleGeometry(0.05, 16);
    const blushL = new THREE.Mesh(blushGeom, blushMat);
    const blushR = new THREE.Mesh(blushGeom, blushMat);
    blushL.position.set(-0.18, -0.12, 0.31);
    blushR.position.set( 0.18, -0.12, 0.31);
    head.add(blushL); head.add(blushR);

    // Smile (a small flattened torus segment)
    const smile = new THREE.Mesh(
      new THREE.TorusGeometry(0.06, 0.012, 8, 16, Math.PI),
      m(PALETTE.mouth)
    );
    smile.position.set(0, -0.13, 0.32);
    smile.rotation.z = Math.PI;
    head.add(smile);

    // ----- Cap (baseball-style) ---------------------------------------
    const capCrown = new THREE.Mesh(
      new THREE.SphereGeometry(0.37, 20, 14, 0, Math.PI * 2, 0, Math.PI / 2),
      m(PALETTE.cap)
    );
    capCrown.position.y = 0.06;
    capCrown.scale.set(1.02, 1, 1.02);
    head.add(capCrown);

    const capBrim = new THREE.Mesh(
      new THREE.CylinderGeometry(0.34, 0.34, 0.04, 24, 1, false, -Math.PI / 2, Math.PI),
      m(PALETTE.capDark)
    );
    capBrim.position.set(0, 0.06, 0.18);
    capBrim.scale.set(1, 1, 1.4);
    head.add(capBrim);

    // Cap button on top
    const capButton = new THREE.Mesh(
      new THREE.SphereGeometry(0.03, 8, 8), m(PALETTE.capDark)
    );
    capButton.position.y = 0.42;
    head.add(capButton);

    // ----- Arms --------------------------------------------------------
    const makeArm = (side) => {
      const shoulder = new THREE.Group();
      shoulder.position.set(side * 0.34, 0.48, 0);
      hips.add(shoulder);

      // Sleeve (orange — same as shirt)
      const sleeve = new THREE.Mesh(
        new THREE.CylinderGeometry(0.13, 0.12, 0.22, 14),
        m(PALETTE.shirt)
      );
      sleeve.position.y = -0.05;
      shoulder.add(sleeve);

      // Forearm pivot
      const forearm = new THREE.Group();
      forearm.position.y = -0.16;
      shoulder.add(forearm);

      const armMesh = new THREE.Mesh(
        new THREE.CylinderGeometry(0.095, 0.085, 0.34, 14),
        m(PALETTE.skin)
      );
      armMesh.position.y = -0.18;
      forearm.add(armMesh);

      // Hand (chunky sphere)
      const hand = new THREE.Mesh(
        new THREE.SphereGeometry(0.11, 14, 12), m(PALETTE.skin)
      );
      hand.position.y = -0.4;
      hand.scale.set(1, 0.9, 1.1);
      forearm.add(hand);

      shoulder.userData.forearm = forearm;
      return shoulder;
    };

    const armL = makeArm(-1);
    const armR = makeArm( 1);

    // ----- Legs --------------------------------------------------------
    const makeLeg = (side) => {
      const hip = new THREE.Group();
      hip.position.set(side * 0.14, -0.18, 0);
      hips.add(hip);

      // Shorts portion
      const shorts = new THREE.Mesh(
        new THREE.CylinderGeometry(0.16, 0.14, 0.28, 14),
        m(PALETTE.pants)
      );
      shorts.position.y = -0.1;
      hip.add(shorts);

      // Lower leg (skin)
      const lower = new THREE.Mesh(
        new THREE.CylinderGeometry(0.105, 0.09, 0.32, 14),
        m(PALETTE.skin)
      );
      lower.position.y = -0.4;
      hip.add(lower);

      // Sock band
      const sock = new THREE.Mesh(
        new THREE.CylinderGeometry(0.11, 0.11, 0.06, 14),
        m(PALETTE.shoe)
      );
      sock.position.y = -0.55;
      hip.add(sock);

      // Sneaker
      const shoe = new THREE.Mesh(
        roundedBox(THREE, 0.24, 0.16, 0.36, 0.07),
        m(PALETTE.shoe)
      );
      shoe.position.set(0, -0.66, 0.05);
      hip.add(shoe);

      const stripe = new THREE.Mesh(
        roundedBox(THREE, 0.245, 0.05, 0.36, 0.025),
        m(PALETTE.shoeAccent)
      );
      stripe.position.set(0, -0.62, 0.05);
      hip.add(stripe);

      return hip;
    };

    const legL = makeLeg(-1);
    const legR = makeLeg( 1);

    // ----- Backpack (compact hiking rucksack with top flap & buckle) --
    const backpack = new THREE.Group();
    backpack.position.set(0, 0.18, -0.2);
    hips.add(backpack);

    // Main body — smaller, slightly rounded, sits on the upper back
    const packBody = new THREE.Mesh(
      roundedBox(THREE, 0.38, 0.48, 0.2, 0.1), m(PALETTE.backpack)
    );
    backpack.add(packBody);

    // Top flap — drapes over the top and a bit down the front of the pack
    const packFlap = new THREE.Mesh(
      roundedBox(THREE, 0.4, 0.18, 0.22, 0.08), m(PALETTE.backpackD)
    );
    packFlap.position.set(0, 0.2, 0.01);
    packFlap.rotation.x = -0.12;
    backpack.add(packFlap);

    // Cinch cord on the flap (yellow accent loop)
    const cinch = new THREE.Mesh(
      new THREE.TorusGeometry(0.05, 0.012, 6, 16),
      m(PALETTE.backpackA)
    );
    cinch.position.set(0, 0.21, 0.13);
    cinch.rotation.x = Math.PI / 2.4;
    backpack.add(cinch);

    // Vertical buckle strap from flap down the front
    const buckleStrap = new THREE.Mesh(
      roundedBox(THREE, 0.05, 0.28, 0.02, 0.012), m(PALETTE.backpackA)
    );
    buckleStrap.position.set(0, 0.04, 0.11);
    backpack.add(buckleStrap);

    // Buckle clasp (small dark square on the strap)
    const buckle = new THREE.Mesh(
      roundedBox(THREE, 0.07, 0.05, 0.025, 0.012), m(PALETTE.camera)
    );
    buckle.position.set(0, 0.0, 0.13);
    backpack.add(buckle);

    // Small side pocket / bottle holder
    const sidePocket = new THREE.Mesh(
      new THREE.CylinderGeometry(0.045, 0.045, 0.18, 12),
      m(PALETTE.backpackD)
    );
    sidePocket.position.set(0.2, -0.08, 0);
    sidePocket.rotation.z = -0.08;
    backpack.add(sidePocket);

    // Straps (over the shoulders, in front of torso)
    const strapMat = m(PALETTE.backpackD);
    const makeStrap = (side) => {
      const s = new THREE.Mesh(
        roundedBox(THREE, 0.07, 0.62, 0.04, 0.02), strapMat
      );
      s.position.set(side * 0.18, 0.32, 0.22);
      s.rotation.x = -0.05;
      hips.add(s);
    };
    makeStrap(-1);
    makeStrap( 1);

    // ----- Camera (around neck, on chest) ------------------------------
    const camera = new THREE.Group();
    camera.position.set(0, 0.28, 0.22);
    hips.add(camera);

    const camBody = new THREE.Mesh(
      roundedBox(THREE, 0.28, 0.18, 0.12, 0.035), m(PALETTE.camera)
    );
    camera.add(camBody);

    const camLens = new THREE.Mesh(
      new THREE.CylinderGeometry(0.07, 0.075, 0.09, 16),
      m(PALETTE.cameraLens)
    );
    camLens.rotation.x = Math.PI / 2;
    camLens.position.z = 0.1;
    camera.add(camLens);

    const camRing = new THREE.Mesh(
      new THREE.TorusGeometry(0.07, 0.012, 8, 24),
      m(PALETTE.cameraRing)
    );
    camRing.position.z = 0.145;
    camera.add(camRing);

    const camFlash = new THREE.Mesh(
      roundedBox(THREE, 0.05, 0.04, 0.02, 0.01), m(PALETTE.shoe)
    );
    camFlash.position.set(-0.08, 0.05, 0.07);
    camera.add(camFlash);

    // Camera strap (a thin curved line draped on neck)
    const strapCurve = new THREE.CatmullRomCurve3([
      new THREE.Vector3(-0.14,  0.74, -0.05),
      new THREE.Vector3(-0.18,  0.5,   0.14),
      new THREE.Vector3( 0.0,   0.3,   0.24),
      new THREE.Vector3( 0.18,  0.5,   0.14),
      new THREE.Vector3( 0.14,  0.74, -0.05),
    ]);
    const strapGeom = new THREE.TubeGeometry(strapCurve, 32, 0.012, 6, false);
    const strapMesh = new THREE.Mesh(strapGeom, m(PALETTE.camera));
    hips.add(strapMesh);

    // ----- Shadow disc (under feet, sits on floor) --------------------
    const shadow = new THREE.Mesh(
      new THREE.CircleGeometry(0.55, 32),
      new THREE.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.18 })
    );
    shadow.rotation.x = -Math.PI / 2;
    shadow.position.y = 0.005;
    root.add(shadow);

    // expose joints for animation
    root.userData = {
      hips, head, armL, armR, legL, legR, eyeL, eyeR, shadow,
    };
    return root;
  }

  // Female palette — teal shirt, purple-navy pants, warm pink headband
  const PALETTE_F = Object.assign({}, PALETTE, {
    shirt:      0x1f9d94,
    shirtDark:  0x147169,
    pants:      0x4a3060,
    pantsDark:  0x2e1c3e,
    cap:        0xd84296,
    capDark:    0xa11e65,
  });

  function buildFemaleCharacter(THREE) {
    const grad = makeToonGradient(THREE);
    const m  = (c) => toonMat(THREE, c, grad);
    const mf = (c) => toonMat(THREE, c, grad); // alias for readability

    const root = new THREE.Group();
    root.name = 'tourist-f';

    const hips = new THREE.Group();
    hips.position.y = 0.95;
    root.add(hips);

    // Torso — same capsule, teal shirt
    const torsoGeom = new THREE.CapsuleGeometry(0.26, 0.42, 8, 18);
    torsoGeom.scale(1.05, 1.0, 0.7);
    const torso = new THREE.Mesh(torsoGeom, m(PALETTE_F.shirt));
    torso.position.y = 0.22;
    torso.castShadow = true;
    hips.add(torso);

    const shoulderYoke = new THREE.Mesh(
      new THREE.SphereGeometry(0.32, 18, 14, 0, Math.PI * 2, 0, Math.PI / 2.2),
      m(PALETTE_F.shirt)
    );
    shoulderYoke.position.y = 0.5;
    shoulderYoke.scale.set(1.05, 0.55, 0.72);
    hips.add(shoulderYoke);

    const collar = new THREE.Mesh(
      new THREE.TorusGeometry(0.13, 0.04, 12, 24),
      m(PALETTE_F.shirtDark)
    );
    collar.position.set(0, 0.58, 0.06);
    collar.rotation.x = Math.PI / 2;
    collar.scale.set(1, 1, 0.55);
    hips.add(collar);

    // Head
    const head = new THREE.Group();
    head.position.y = 0.78;
    hips.add(head);

    const headMesh = new THREE.Mesh(
      new THREE.SphereGeometry(0.36, 24, 20),
      m(PALETTE.skin)
    );
    headMesh.scale.set(1, 0.95, 0.92);
    headMesh.castShadow = true;
    head.add(headMesh);

    // Hair — longer, covers more of head, no cap
    const hairMain = new THREE.Mesh(
      new THREE.SphereGeometry(0.37, 20, 16),
      m(PALETTE.hair)
    );
    hairMain.scale.set(1.0, 0.95, 0.96);
    head.add(hairMain);

    // Ponytail — extends behind
    const tailBase = new THREE.Mesh(
      new THREE.CylinderGeometry(0.1, 0.08, 0.28, 12),
      m(PALETTE.hair)
    );
    tailBase.position.set(0, -0.08, -0.3);
    tailBase.rotation.x = 0.5;
    head.add(tailBase);

    const tailTip = new THREE.Mesh(
      new THREE.SphereGeometry(0.1, 12, 10),
      m(PALETTE.hair)
    );
    tailTip.position.set(0, -0.26, -0.46);
    head.add(tailTip);

    // Headband (pink accent)
    const headband = new THREE.Mesh(
      new THREE.TorusGeometry(0.355, 0.025, 8, 28, Math.PI * 2),
      m(PALETTE_F.cap)
    );
    headband.position.y = 0.08;
    headband.rotation.x = 0.12;
    headband.scale.set(1.0, 0.55, 1.0);
    head.add(headband);

    // Eyes, blush, smile — identical to male
    const eyeMat = m(0x1a1a22);
    const eyeGeom = new THREE.SphereGeometry(0.045, 12, 12);
    const eyeL = new THREE.Mesh(eyeGeom, eyeMat);
    const eyeR = new THREE.Mesh(eyeGeom, eyeMat);
    eyeL.position.set(-0.12, -0.02, 0.31);
    eyeR.position.set( 0.12, -0.02, 0.31);
    eyeL.scale.set(1, 1.2, 0.6);
    eyeR.scale.set(1, 1.2, 0.6);
    head.add(eyeL); head.add(eyeR);

    const blushMat = m(0xe88c7a);
    const blushGeom = new THREE.CircleGeometry(0.05, 16);
    const blushL = new THREE.Mesh(blushGeom, blushMat);
    const blushR = new THREE.Mesh(blushGeom, blushMat);
    blushL.position.set(-0.18, -0.12, 0.31);
    blushR.position.set( 0.18, -0.12, 0.31);
    head.add(blushL); head.add(blushR);

    const smile = new THREE.Mesh(
      new THREE.TorusGeometry(0.06, 0.012, 8, 16, Math.PI),
      m(PALETTE.mouth)
    );
    smile.position.set(0, -0.13, 0.32);
    smile.rotation.z = Math.PI;
    head.add(smile);

    // Arms — same as male but teal sleeve
    const makeArm = (side) => {
      const shoulder = new THREE.Group();
      shoulder.position.set(side * 0.34, 0.48, 0);
      hips.add(shoulder);

      const sleeve = new THREE.Mesh(
        new THREE.CylinderGeometry(0.13, 0.12, 0.22, 14),
        m(PALETTE_F.shirt)
      );
      sleeve.position.y = -0.05;
      shoulder.add(sleeve);

      const forearm = new THREE.Group();
      forearm.position.y = -0.16;
      shoulder.add(forearm);

      const armMesh = new THREE.Mesh(
        new THREE.CylinderGeometry(0.095, 0.085, 0.34, 14),
        m(PALETTE.skin)
      );
      armMesh.position.y = -0.18;
      forearm.add(armMesh);

      const hand = new THREE.Mesh(
        new THREE.SphereGeometry(0.11, 14, 12), m(PALETTE.skin)
      );
      hand.position.y = -0.4;
      hand.scale.set(1, 0.9, 1.1);
      forearm.add(hand);

      shoulder.userData.forearm = forearm;
      return shoulder;
    };

    const armL = makeArm(-1);
    const armR = makeArm( 1);

    // Legs — purple pants
    const makeLeg = (side) => {
      const hip = new THREE.Group();
      hip.position.set(side * 0.14, -0.18, 0);
      hips.add(hip);

      const shorts = new THREE.Mesh(
        new THREE.CylinderGeometry(0.16, 0.14, 0.28, 14),
        m(PALETTE_F.pants)
      );
      shorts.position.y = -0.1;
      hip.add(shorts);

      const lower = new THREE.Mesh(
        new THREE.CylinderGeometry(0.105, 0.09, 0.32, 14),
        m(PALETTE.skin)
      );
      lower.position.y = -0.4;
      hip.add(lower);

      const sock = new THREE.Mesh(
        new THREE.CylinderGeometry(0.11, 0.11, 0.06, 14),
        m(PALETTE.shoe)
      );
      sock.position.y = -0.55;
      hip.add(sock);

      const shoe = new THREE.Mesh(
        roundedBox(THREE, 0.24, 0.16, 0.36, 0.07),
        m(PALETTE.shoe)
      );
      shoe.position.set(0, -0.66, 0.05);
      hip.add(shoe);

      const stripe = new THREE.Mesh(
        roundedBox(THREE, 0.245, 0.05, 0.36, 0.025),
        m(PALETTE_F.cap)
      );
      stripe.position.set(0, -0.62, 0.05);
      hip.add(stripe);

      return hip;
    };

    const legL = makeLeg(-1);
    const legR = makeLeg( 1);

    // Backpack — same as male
    const backpack = new THREE.Group();
    backpack.position.set(0, 0.18, -0.2);
    hips.add(backpack);

    const packBody = new THREE.Mesh(
      roundedBox(THREE, 0.38, 0.48, 0.2, 0.1), m(PALETTE.backpack)
    );
    backpack.add(packBody);

    const packFlap = new THREE.Mesh(
      roundedBox(THREE, 0.4, 0.18, 0.22, 0.08), m(PALETTE.backpackD)
    );
    packFlap.position.set(0, 0.2, 0.01);
    packFlap.rotation.x = -0.12;
    backpack.add(packFlap);

    const cinch = new THREE.Mesh(
      new THREE.TorusGeometry(0.05, 0.012, 6, 16),
      m(PALETTE.backpackA)
    );
    cinch.position.set(0, 0.21, 0.13);
    cinch.rotation.x = Math.PI / 2.4;
    backpack.add(cinch);

    const buckleStrap = new THREE.Mesh(
      roundedBox(THREE, 0.05, 0.28, 0.02, 0.012), m(PALETTE.backpackA)
    );
    buckleStrap.position.set(0, 0.04, 0.11);
    backpack.add(buckleStrap);

    const buckle = new THREE.Mesh(
      roundedBox(THREE, 0.07, 0.05, 0.025, 0.012), m(PALETTE.camera)
    );
    buckle.position.set(0, 0.0, 0.13);
    backpack.add(buckle);

    const sidePocket = new THREE.Mesh(
      new THREE.CylinderGeometry(0.045, 0.045, 0.18, 12),
      m(PALETTE.backpackD)
    );
    sidePocket.position.set(0.2, -0.08, 0);
    sidePocket.rotation.z = -0.08;
    backpack.add(sidePocket);

    const strapMat = m(PALETTE.backpackD);
    const makeStrap = (side) => {
      const s = new THREE.Mesh(
        roundedBox(THREE, 0.07, 0.62, 0.04, 0.02), strapMat
      );
      s.position.set(side * 0.18, 0.32, 0.22);
      s.rotation.x = -0.05;
      hips.add(s);
    };
    makeStrap(-1);
    makeStrap( 1);

    // Camera — same as male
    const camera = new THREE.Group();
    camera.position.set(0, 0.28, 0.22);
    hips.add(camera);

    const camBody = new THREE.Mesh(
      roundedBox(THREE, 0.28, 0.18, 0.12, 0.035), m(PALETTE.camera)
    );
    camera.add(camBody);

    const camLens = new THREE.Mesh(
      new THREE.CylinderGeometry(0.07, 0.075, 0.09, 16),
      m(PALETTE.cameraLens)
    );
    camLens.rotation.x = Math.PI / 2;
    camLens.position.z = 0.1;
    camera.add(camLens);

    const camRing = new THREE.Mesh(
      new THREE.TorusGeometry(0.07, 0.012, 8, 24),
      m(PALETTE.cameraRing)
    );
    camRing.position.z = 0.145;
    camera.add(camRing);

    const strapCurve = new THREE.CatmullRomCurve3([
      new THREE.Vector3(-0.14,  0.74, -0.05),
      new THREE.Vector3(-0.18,  0.5,   0.14),
      new THREE.Vector3( 0.0,   0.3,   0.24),
      new THREE.Vector3( 0.18,  0.5,   0.14),
      new THREE.Vector3( 0.14,  0.74, -0.05),
    ]);
    const strapGeom = new THREE.TubeGeometry(strapCurve, 32, 0.012, 6, false);
    const strapMesh = new THREE.Mesh(strapGeom, m(PALETTE.camera));
    hips.add(strapMesh);

    const shadow = new THREE.Mesh(
      new THREE.CircleGeometry(0.55, 32),
      new THREE.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.18 })
    );
    shadow.rotation.x = -Math.PI / 2;
    shadow.position.y = 0.005;
    root.add(shadow);

    root.userData = {
      hips, head, armL, armR, legL, legR, eyeL, eyeR, shadow,
    };
    return root;
  }

  // ----------------------------------------------------------------------
  //  Animations — pure procedural, no external clips needed.
  // ----------------------------------------------------------------------
  const ANIMATIONS = {
    idle(joints, t) {
      const { hips, head, armL, armR, legL, legR } = joints;
      const breath = Math.sin(t * 1.6) * 0.025;
      hips.position.y = 0.95 + breath;
      hips.rotation.y = Math.sin(t * 0.6) * 0.08;
      head.rotation.y = Math.sin(t * 0.5 + 0.6) * 0.18;
      head.rotation.x = Math.sin(t * 0.4) * 0.04;
      armL.rotation.z =  0.08 + Math.sin(t * 1.6) * 0.02;
      armR.rotation.z = -0.08 - Math.sin(t * 1.6) * 0.02;
      armL.rotation.x = 0; armR.rotation.x = 0;
      legL.rotation.x = 0; legR.rotation.x = 0;
    },
    walk(joints, t) {
      const { hips, head, armL, armR, legL, legR } = joints;
      const s = t * 6;
      hips.position.y = 0.95 + Math.abs(Math.sin(s)) * 0.04;
      hips.rotation.y = Math.sin(s) * 0.12;
      head.rotation.y = Math.sin(s * 0.5) * 0.15;
      head.rotation.x = -0.04;
      armL.rotation.x =  Math.sin(s) * 0.9;
      armR.rotation.x = -Math.sin(s) * 0.9;
      armL.rotation.z =  0.08;
      armR.rotation.z = -0.08;
      legL.rotation.x = -Math.sin(s) * 0.7;
      legR.rotation.x =  Math.sin(s) * 0.7;
    },
    wave(joints, t) {
      const { hips, head, armL, armR, legL, legR } = joints;
      hips.position.y = 0.95 + Math.sin(t * 1.5) * 0.02;
      hips.rotation.y = Math.sin(t * 0.8) * 0.08;
      head.rotation.y = -0.15 + Math.sin(t * 2) * 0.06;
      head.rotation.z =  0.05;
      armL.rotation.z =  0.08;
      armL.rotation.x =  0;
      armR.rotation.z = -2.0;
      armR.rotation.x = -0.15;
      const wave = Math.sin(t * 6) * 0.45;
      armR.userData.forearm.rotation.z = wave;
      armR.userData.forearm.rotation.x = -0.2;
      armL.userData.forearm.rotation.set(0, 0, 0);
      legL.rotation.x = 0; legR.rotation.x = 0;
    },
  };

  // Blink overlay — applied on top of any animation
  function applyBlink(joints, t) {
    const cycle = t % 4.5;
    const blinking = cycle > 4.2;
    const sy = blinking ? 0.1 : 1.2;
    joints.eyeL.scale.y = sy;
    joints.eyeR.scale.y = sy;
  }

  // ----------------------------------------------------------------------
  //  Public mount() — owns the renderer for one host element
  // ----------------------------------------------------------------------
  function mount(host, opts) {
    opts = Object.assign({
      background: 'transparent',
      animation: 'idle',
      autoRotate: false,
      gender: 'male',
      pixelRatio: Math.min(window.devicePixelRatio || 1, 2),
    }, opts || {});

    // Scene ----------------------------------------------------------
    const scene = new THREE.Scene();
    if (opts.background !== 'transparent') {
      scene.background = new THREE.Color(opts.background);
    }

    // Camera — behind the character (3rd-person back view)
    const aspect = host.clientWidth / Math.max(host.clientHeight, 1);
    const cam = new THREE.PerspectiveCamera(28, aspect, 0.1, 50);
    cam.position.set(0, 1.8, -5.6);
    cam.lookAt(0, 1.1, 0);

    // Lights — rim (formerly back-light) is now the main key from behind
    const key = new THREE.DirectionalLight(0xfff2dc, 0.55);
    key.position.set(3, 5, 4);
    scene.add(key);

    const fill = new THREE.DirectionalLight(0xc7d6ff, 0.35);
    fill.position.set(-4, 2, 2);
    scene.add(fill);

    const rim = new THREE.DirectionalLight(0xffd6a8, 1.1);
    rim.position.set(0, 3, -4);
    scene.add(rim);

    scene.add(new THREE.AmbientLight(0xffffff, 0.55));

    // Character — male or female variant
    const tourist = opts.gender === 'female'
      ? buildFemaleCharacter(THREE)
      : buildCharacter(THREE);
    scene.add(tourist);

    // Renderer -------------------------------------------------------
    const renderer = new THREE.WebGLRenderer({
      antialias: true,
      alpha: opts.background === 'transparent',
    });
    renderer.setPixelRatio(opts.pixelRatio);
    renderer.setSize(host.clientWidth, host.clientHeight, false);
    if (opts.background === 'transparent') renderer.setClearColor(0x000000, 0);
    renderer.outputColorSpace = THREE.SRGBColorSpace || THREE.sRGBEncoding;
    renderer.domElement.style.display = 'block';
    renderer.domElement.style.width = '100%';
    renderer.domElement.style.height = '100%';
    host.appendChild(renderer.domElement);

    // Resize observer ------------------------------------------------
    const ro = new ResizeObserver(() => {
      const w = host.clientWidth, h = Math.max(host.clientHeight, 1);
      renderer.setSize(w, h, false);
      cam.aspect = w / h;
      cam.updateProjectionMatrix();
    });
    ro.observe(host);

    // Animate --------------------------------------------------------
    let current = opts.animation;
    let raf = 0;
    const start = performance.now();
    let alive = true;

    function frame() {
      if (!alive) return;
      const t = (performance.now() - start) / 1000;
      const fn = ANIMATIONS[current] || ANIMATIONS.idle;
      fn(tourist.userData, t);
      applyBlink(tourist.userData, t);
      if (opts.autoRotate) tourist.rotation.y = t * 0.3;
      renderer.render(scene, cam);
      raf = requestAnimationFrame(frame);
    }
    raf = requestAnimationFrame(frame);

    // Public API -----------------------------------------------------
    return {
      play(name) { current = ANIMATIONS[name] ? name : 'idle'; },
      setRotation(yaw) { tourist.rotation.y = yaw; },
      setAutoRotate(v) { opts.autoRotate = !!v; },
      get character() { return tourist; },
      get renderer() { return renderer; },
      dispose() {
        alive = false;
        cancelAnimationFrame(raf);
        ro.disconnect();
        renderer.dispose();
        if (renderer.domElement.parentNode) {
          renderer.domElement.parentNode.removeChild(renderer.domElement);
        }
        scene.traverse((obj) => {
          if (obj.geometry) obj.geometry.dispose();
          if (obj.material) {
            const mats = Array.isArray(obj.material) ? obj.material : [obj.material];
            mats.forEach((m) => {
              if (m.map) m.map.dispose();
              if (m.gradientMap) m.gradientMap.dispose();
              m.dispose();
            });
          }
        });
      },
    };
  }

  root.FactTourist = { mount, PALETTE };
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { mount, PALETTE };
  }
})(typeof window !== 'undefined' ? window : globalThis);
