import math
import os
import bpy

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sprites")


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def setup_render_and_camera():
    scene = bpy.context.scene

    # Select EEVEE render engine across Blender 4.x / 5.x
    available_engines = {e.identifier for e in scene.render.bl_rna.properties["engine"].enum_items}
    if "BLENDER_EEVEE_NEXT" in available_engines:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    elif "BLENDER_EEVEE" in available_engines:
        scene.render.engine = "BLENDER_EEVEE"

    # Use Standard view transform for vibrant, saturated cel-shaded toon colors
    try:
        scene.view_settings.view_transform = "Standard"
    except Exception:
        pass

    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"

    # Orthographic camera looking towards origin from -Y
    cam_data = bpy.data.cameras.new(name="OrthoCamera")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 3.5
    cam_obj = bpy.data.objects.new("OrthoCamera", cam_data)
    scene.collection.objects.link(cam_obj)
    cam_obj.location = (0.0, -6.0, 0.15)
    cam_obj.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    scene.camera = cam_obj

    # 3-Point Lighting Setup
    # 1. Key Light (Front-Left-Top)
    key_data = bpy.data.lights.new(name="KeyLight", type="SUN")
    key_data.energy = 3.8
    key_data.color = (1.0, 0.98, 0.95)
    key_obj = bpy.data.objects.new(name="KeyLight", object_data=key_data)
    scene.collection.objects.link(key_obj)
    key_obj.location = (-3.5, -4.0, 4.5)
    key_obj.rotation_euler = (math.radians(48.0), math.radians(-20.0), math.radians(-35.0))

    # 2. Fill Light (Front-Right)
    fill_data = bpy.data.lights.new(name="FillLight", type="SUN")
    fill_data.energy = 1.2
    fill_data.color = (0.75, 0.85, 1.0)
    fill_obj = bpy.data.objects.new(name="FillLight", object_data=fill_data)
    scene.collection.objects.link(fill_obj)
    fill_obj.location = (3.5, -3.5, 1.5)
    fill_obj.rotation_euler = (math.radians(65.0), math.radians(15.0), math.radians(40.0))

    # 3. Rim / Back Light (Back-Top)
    rim_data = bpy.data.lights.new(name="RimLight", type="SUN")
    rim_data.energy = 2.8
    rim_data.color = (0.9, 0.95, 1.0)
    rim_obj = bpy.data.objects.new(name="RimLight", object_data=rim_data)
    scene.collection.objects.link(rim_obj)
    rim_obj.location = (0.0, 4.0, 4.0)
    rim_obj.rotation_euler = (math.radians(-45.0), 0.0, math.radians(180.0))

    return scene, cam_obj


def create_toon_material(name, shadow_color, mid_color, highlight_color, emission_strength=0.0):
    """Creates a flat toon shader using Diffuse BSDF -> Shader to RGB -> ColorRamp (CONSTANT)."""
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    output_node = nodes.new(type="ShaderNodeOutputMaterial")
    output_node.location = (600, 0)

    diffuse = nodes.new(type="ShaderNodeBsdfDiffuse")
    diffuse.location = (-250, 0)
    diffuse.inputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)

    shader_to_rgb = nodes.new(type="ShaderNodeShaderToRGB")
    shader_to_rgb.location = (-50, 0)

    ramp = nodes.new(type="ShaderNodeValToRGB")
    ramp.location = (150, 0)
    ramp.color_ramp.interpolation = "CONSTANT"

    e0 = ramp.color_ramp.elements[0]
    e0.position = 0.0
    e0.color = (*shadow_color, 1.0)

    e1 = ramp.color_ramp.elements[1]
    e1.position = 0.25
    e1.color = (*mid_color, 1.0)

    e2 = ramp.color_ramp.elements.new(0.62)
    e2.color = (*highlight_color, 1.0)

    links.new(diffuse.outputs["BSDF"], shader_to_rgb.inputs["Shader"])
    links.new(shader_to_rgb.outputs["Color"], ramp.inputs["Fac"])

    if emission_strength > 0.0:
        emission = nodes.new(type="ShaderNodeEmission")
        emission.location = (400, 0)
        emission.inputs["Strength"].default_value = emission_strength
        links.new(ramp.outputs["Color"], emission.inputs["Color"])
        links.new(emission.outputs["Emission"], output_node.inputs["Surface"])
    else:
        links.new(ramp.outputs["Color"], output_node.inputs["Surface"])

    return mat


def assign_mat(obj, mat):
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)


def add_bevel(obj, width=0.05, segments=2):
    mod = obj.modifiers.new(name="Bevel", type="BEVEL")
    mod.width = width
    mod.segments = segments


def build_cyber_knight():
    """Cyber Knight: Heavy futuristic armored paladin silhouette with glowing cyan visor and core."""
    armor_steel = create_toon_material(
        "KnightSteel", (0.12, 0.20, 0.34), (0.24, 0.38, 0.58), (0.46, 0.66, 0.90)
    )
    armor_dark = create_toon_material(
        "KnightDark", (0.06, 0.09, 0.15), (0.14, 0.19, 0.28), (0.24, 0.32, 0.44)
    )
    neon_cyan = create_toon_material(
        "KnightCyan", (0.0, 0.55, 0.85), (0.05, 0.85, 1.0), (0.55, 0.98, 1.0), emission_strength=1.4
    )
    gold_trim = create_toon_material(
        "KnightGold", (0.45, 0.26, 0.05), (0.85, 0.58, 0.12), (1.0, 0.84, 0.28)
    )

    # Neck / Upper Spine Connector
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.32, depth=0.65, location=(0.0, 0.0, 0.68))
    neck = bpy.context.active_object
    assign_mat(neck, armor_dark)

    # Armored Chestplate
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0.0, 0.0, 0.12))
    chest = bpy.context.active_object
    chest.scale = (0.72, 0.44, 0.52)
    add_bevel(chest, 0.07)
    assign_mat(chest, armor_steel)

    # Lower Torso / Waist Core
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.56, depth=0.75, location=(0.0, 0.0, -0.52))
    waist = bpy.context.active_object
    waist.scale = (1.0, 0.68, 1.0)
    assign_mat(waist, armor_dark)

    # Armored Belt & Pelvis Guard
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0.0, -0.05, -0.78))
    belt = bpy.context.active_object
    belt.scale = (0.62, 0.42, 0.12)
    assign_mat(belt, gold_trim)

    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0.0, -0.08, -0.98))
    pelvis = bpy.context.active_object
    pelvis.scale = (0.24, 0.36, 0.22)
    assign_mat(pelvis, armor_steel)

    for side in (-1, 1):
        # Heavy Layered Pauldrons (Connected to Chest)
        bpy.ops.mesh.primitive_cube_add(size=2.0, location=(side * 0.92, 0.0, 0.46))
        pauldron = bpy.context.active_object
        pauldron.scale = (0.38, 0.46, 0.34)
        pauldron.rotation_euler = (0.0, side * math.radians(16.0), 0.0)
        add_bevel(pauldron, 0.07)
        assign_mat(pauldron, armor_steel)

        # Pauldron Golden Crest Wing
        bpy.ops.mesh.primitive_cube_add(size=2.0, location=(side * 0.98, 0.0, 0.72))
        ridge = bpy.context.active_object
        ridge.scale = (0.28, 0.34, 0.11)
        ridge.rotation_euler = (0.0, side * math.radians(24.0), 0.0)
        assign_mat(ridge, gold_trim)

        # Pauldron Neon Strip
        bpy.ops.mesh.primitive_cube_add(size=2.0, location=(side * 0.94, -0.40, 0.44))
        p_glow = bpy.context.active_object
        p_glow.scale = (0.22, 0.10, 0.06)
        p_glow.rotation_euler = (0.0, side * math.radians(16.0), 0.0)
        assign_mat(p_glow, neon_cyan)

        # Upper Arm + Armored Gauntlets
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=10, radius=0.23, depth=0.85, location=(side * 0.95, -0.05, -0.15)
        )
        arm = bpy.context.active_object
        arm.rotation_euler = (math.radians(10.0), side * math.radians(-8.0), 0.0)
        assign_mat(arm, armor_dark)

        bpy.ops.mesh.primitive_cube_add(size=2.0, location=(side * 0.98, -0.14, -0.45))
        gauntlet = bpy.context.active_object
        gauntlet.scale = (0.22, 0.25, 0.30)
        gauntlet.rotation_euler = (math.radians(12.0), side * math.radians(-10.0), 0.0)
        add_bevel(gauntlet, 0.05)
        assign_mat(gauntlet, armor_steel)

        # Armored Thighs & Greaves (Connected to Belt)
        bpy.ops.mesh.primitive_cube_add(size=2.0, location=(side * 0.38, 0.0, -1.22))
        leg = bpy.context.active_object
        leg.scale = (0.23, 0.28, 0.38)
        add_bevel(leg, 0.04)
        assign_mat(leg, armor_steel)

    # Glowing Cyber Reactor Core on Chest
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6,
        radius=0.28,
        depth=0.22,
        location=(0.0, -0.42, 0.16),
        rotation=(math.radians(90.0), 0.0, 0.0),
    )
    core = bpy.context.active_object
    assign_mat(core, neon_cyan)

    # Angular Crusader Cyber Helmet
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.45, depth=0.72, location=(0.0, -0.04, 1.08))
    helm = bpy.context.active_object
    helm.scale = (0.95, 1.05, 1.0)
    add_bevel(helm, 0.06)
    assign_mat(helm, armor_steel)

    # Helmet Crest / Fin
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0.0, 0.0, 1.48))
    crest = bpy.context.active_object
    crest.scale = (0.08, 0.38, 0.16)
    add_bevel(crest, 0.02)
    assign_mat(crest, gold_trim)

    # Glowing T-Visor
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0.0, -0.45, 1.12))
    visor_h = bpy.context.active_object
    visor_h.scale = (0.28, 0.08, 0.05)
    assign_mat(visor_h, neon_cyan)

    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0.0, -0.45, 0.98))
    visor_v = bpy.context.active_object
    visor_v.scale = (0.05, 0.08, 0.13)
    assign_mat(visor_v, neon_cyan)


def build_shadow_ranger():
    """Shadow Ranger: Hooded stealth sniper/assassin figure with glowing emerald eyes and cloak."""
    cloak_mat = create_toon_material(
        "RangerCloak", (0.05, 0.15, 0.11), (0.10, 0.28, 0.20), (0.20, 0.48, 0.34)
    )
    shadow_inner = create_toon_material(
        "RangerShadow", (0.02, 0.03, 0.03), (0.04, 0.06, 0.06), (0.08, 0.11, 0.12)
    )
    leather_mat = create_toon_material(
        "RangerLeather", (0.18, 0.11, 0.06), (0.34, 0.21, 0.12), (0.52, 0.34, 0.20)
    )
    neon_emerald = create_toon_material(
        "RangerEmerald", (0.0, 0.65, 0.22), (0.10, 0.95, 0.40), (0.55, 1.0, 0.72), emission_strength=1.5
    )

    # Flowing Cloak Silhouette Body
    bpy.ops.mesh.primitive_cone_add(
        vertices=14, radius1=1.18, radius2=0.52, depth=2.15, location=(0.0, 0.05, -0.35)
    )
    cloak = bpy.context.active_object
    cloak.scale = (0.95, 0.60, 1.0)
    assign_mat(cloak, cloak_mat)

    # Tactical Chest Harness
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0.0, -0.15, 0.05))
    chest = bpy.context.active_object
    chest.scale = (0.48, 0.26, 0.44)
    add_bevel(chest, 0.05)
    assign_mat(chest, leather_mat)

    # Diagonal Bandolier Strap
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0.0, -0.38, 0.08))
    strap = bpy.context.active_object
    strap.scale = (0.52, 0.07, 0.08)
    strap.rotation_euler = (0.0, math.radians(36.0), 0.0)
    assign_mat(strap, leather_mat)

    # Glowing Energy Vials on Bandolier
    for offset in (-0.26, 0.0, 0.26):
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8,
            radius=0.065,
            depth=0.24,
            location=(offset, -0.45, 0.08 - offset * 0.72),
        )
        vial = bpy.context.active_object
        assign_mat(vial, neon_emerald)

    # Asymmetric Shoulder Mantle / Scarf
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.56, minor_radius=0.22, location=(0.0, -0.05, 0.62)
    )
    cowl = bpy.context.active_object
    cowl.scale = (1.15, 0.78, 0.85)
    assign_mat(cowl, cloak_mat)

    # Deep Pointed Ranger Hood (Outer Shell tilted back slightly to reveal shadowed face)
    bpy.ops.mesh.primitive_cone_add(
        vertices=14, radius1=0.68, radius2=0.05, depth=1.18, location=(0.0, 0.08, 1.24)
    )
    hood = bpy.context.active_object
    hood.scale = (0.94, 0.95, 1.0)
    assign_mat(hood, cloak_mat)

    # Dark Hood Interior Shadow Face (Positioned forward inside hood opening)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.40, location=(0.0, -0.22, 1.02))
    face = bpy.context.active_object
    face.scale = (0.92, 0.75, 1.05)
    assign_mat(face, shadow_inner)

    # Stealth Respirator Mask
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0.0, -0.48, 0.90))
    mask = bpy.context.active_object
    mask.scale = (0.16, 0.12, 0.12)
    mask.rotation_euler = (0.0, math.radians(45.0), 0.0)
    assign_mat(mask, leather_mat)

    # Glowing Emerald Slanted Eyes inside Hood Shadow
    for side in (-1, 1):
        bpy.ops.mesh.primitive_cube_add(size=2.0, location=(side * 0.15, -0.53, 1.06))
        eye = bpy.context.active_object
        eye.scale = (0.085, 0.04, 0.03)
        eye.rotation_euler = (0.0, side * math.radians(-18.0), 0.0)
        assign_mat(eye, neon_emerald)

    # Quiver / Tactical Arrows protruding behind right shoulder
    for idx in range(3):
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8,
            radius=0.045,
            depth=1.15,
            location=(0.55 + idx * 0.12, 0.25, 1.12 + idx * 0.08),
            rotation=(0.0, math.radians(24.0), 0.0),
        )
        shaft = bpy.context.active_object
        assign_mat(shaft, leather_mat)

        bpy.ops.mesh.primitive_cone_add(
            vertices=6,
            radius1=0.09,
            radius2=0.01,
            depth=0.22,
            location=(0.76 + idx * 0.12, 0.25, 1.60 + idx * 0.08),
            rotation=(0.0, math.radians(24.0), 0.0),
        )
        tip = bpy.context.active_object
        assign_mat(tip, neon_emerald)


def build_arcane_mage():
    """Arcane Mage: Robed mystic figure with high collar and floating glowing crystal + arcane rings."""
    robe_purple = create_toon_material(
        "MageRobe", (0.16, 0.06, 0.34), (0.34, 0.14, 0.64), (0.56, 0.30, 0.88)
    )
    trim_gold = create_toon_material(
        "MageGold", (0.45, 0.28, 0.06), (0.86, 0.60, 0.14), (1.0, 0.86, 0.34)
    )
    crystal_magenta = create_toon_material(
        "MageCrystal", (0.65, 0.08, 0.78), (0.95, 0.25, 1.0), (1.0, 0.68, 1.0), emission_strength=1.5
    )
    void_face = create_toon_material(
        "MageFace", (0.04, 0.01, 0.08), (0.08, 0.03, 0.14), (0.14, 0.06, 0.22)
    )

    # Layered Arcane Robe Body
    bpy.ops.mesh.primitive_cone_add(
        vertices=14, radius1=1.10, radius2=0.45, depth=2.10, location=(0.0, 0.0, -0.42)
    )
    robe = bpy.context.active_object
    robe.scale = (0.95, 0.62, 1.0)
    assign_mat(robe, robe_purple)

    # Golden Central Rune Tabard
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0.0, -0.35, -0.42))
    tabard = bpy.context.active_object
    tabard.scale = (0.18, 0.10, 0.68)
    assign_mat(tabard, trim_gold)

    # High Dramatic Arcane Collar
    bpy.ops.mesh.primitive_cone_add(
        vertices=12, radius1=0.38, radius2=0.88, depth=0.72, location=(0.0, 0.08, 0.78)
    )
    collar = bpy.context.active_object
    collar.scale = (1.1, 0.65, 1.0)
    assign_mat(collar, trim_gold)

    # Mage Hood & Head
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.40, location=(0.0, -0.14, 0.96))
    head = bpy.context.active_object
    assign_mat(head, void_face)

    bpy.ops.mesh.primitive_cone_add(
        vertices=12, radius1=0.52, radius2=0.05, depth=0.95, location=(0.0, 0.02, 1.26)
    )
    hood = bpy.context.active_object
    assign_mat(hood, robe_purple)

    # Glowing Arcane Eyes
    for side in (-1, 1):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.065, location=(side * 0.14, -0.50, 0.96))
        eye = bpy.context.active_object
        assign_mat(eye, crystal_magenta)

    # Outstretched Robed Arms Channeling Magic
    for side in (-1, 1):
        bpy.ops.mesh.primitive_cone_add(
            vertices=10,
            radius1=0.34,
            radius2=0.18,
            depth=0.95,
            location=(side * 0.85, -0.12, 0.18),
            rotation=(0.0, side * math.radians(-52.0), 0.0),
        )
        sleeve = bpy.context.active_object
        assign_mat(sleeve, robe_purple)

        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.22,
            minor_radius=0.045,
            location=(side * 1.15, -0.15, 0.35),
            rotation=(0.0, side * math.radians(-52.0), 0.0),
        )
        cuff = bpy.context.active_object
        assign_mat(cuff, trim_gold)

    # Floating Faceted Arcane Crystal (Center-Front / Above Hands)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.36, location=(0.0, -0.65, 0.25))
    crystal = bpy.context.active_object
    crystal.scale = (0.72, 0.72, 1.35)
    crystal.rotation_euler = (math.radians(15.0), math.radians(12.0), math.radians(25.0))
    assign_mat(crystal, crystal_magenta)

    # Orbiting Golden Runic Rings around Floating Crystal
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.54,
        minor_radius=0.035,
        location=(0.0, -0.65, 0.25),
        rotation=(math.radians(55.0), math.radians(25.0), 0.0),
    )
    ring1 = bpy.context.active_object
    assign_mat(ring1, trim_gold)

    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.64,
        minor_radius=0.028,
        location=(0.0, -0.65, 0.25),
        rotation=(math.radians(65.0), math.radians(-35.0), 0.0),
    )
    ring2 = bpy.context.active_object
    assign_mat(ring2, crystal_magenta)

    # Smaller Floating Crystal Shards
    for side in (-1, 1):
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=1, radius=0.16, location=(side * 1.18, -0.45, 0.92)
        )
        shard = bpy.context.active_object
        shard.scale = (0.6, 0.6, 1.35)
        shard.rotation_euler = (0.0, side * math.radians(22.0), 0.0)
        assign_mat(shard, crystal_magenta)


def parent_and_rotate(objects, angle_deg=-38.0, offset=(0.0, 0.0, 0.15)):
    root = bpy.data.objects.new("WeaponRoot", None)
    bpy.context.scene.collection.objects.link(root)
    for obj in objects:
        obj.parent = root
    root.rotation_euler = (0.0, math.radians(angle_deg), 0.0)
    root.location = offset


def build_plasma_blade():
    """Plasma Blade: High-tech melee energy greatsword angled diagonally."""
    hilt_metal = create_toon_material(
        "BladeMetal", (0.14, 0.18, 0.28), (0.28, 0.36, 0.50), (0.54, 0.64, 0.82)
    )
    grip_dark = create_toon_material(
        "BladeGrip", (0.06, 0.08, 0.12), (0.14, 0.17, 0.24), (0.25, 0.30, 0.40)
    )
    plasma_glow = create_toon_material(
        "BladePlasma", (0.0, 0.55, 0.88), (0.08, 0.88, 1.0), (0.62, 0.98, 1.0), emission_strength=1.5
    )
    gold_accent = create_toon_material(
        "BladeAccent", (0.45, 0.25, 0.05), (0.88, 0.58, 0.12), (1.0, 0.86, 0.32)
    )

    objs = []

    # Pommel
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.22, location=(0.0, 0.0, -1.42))
    pommel = bpy.context.active_object
    assign_mat(pommel, gold_accent)
    objs.append(pommel)

    # Grip
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.13, depth=0.72, location=(0.0, 0.0, -1.00))
    grip = bpy.context.active_object
    assign_mat(grip, grip_dark)
    objs.append(grip)

    # Futuristic Crossguard Wings (Connected seamlessly)
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0.0, 0.0, -0.60))
    guard = bpy.context.active_object
    guard.scale = (0.58, 0.16, 0.12)
    add_bevel(guard, 0.03)
    assign_mat(guard, hilt_metal)
    objs.append(guard)

    for side in (-1, 1):
        bpy.ops.mesh.primitive_cube_add(size=2.0, location=(side * 0.54, 0.0, -0.52))
        wing = bpy.context.active_object
        wing.scale = (0.18, 0.14, 0.20)
        wing.rotation_euler = (0.0, side * math.radians(-28.0), 0.0)
        assign_mat(wing, gold_accent)
        objs.append(wing)

    # Crossguard Plasma Core
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6,
        radius=0.20,
        depth=0.38,
        location=(0.0, 0.0, -0.58),
        rotation=(math.radians(90.0), 0.0, 0.0),
    )
    core = bpy.context.active_object
    assign_mat(core, plasma_glow)
    objs.append(core)

    # Outer Glowing Plasma Edge Blade (Connected directly to Crossguard)
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0.0, 0.0, 0.26))
    outer_blade = bpy.context.active_object
    outer_blade.scale = (0.24, 0.05, 0.78)
    assign_mat(outer_blade, plasma_glow)
    objs.append(outer_blade)

    # Plasma Blade Pointed Tip
    bpy.ops.mesh.primitive_cone_add(
        vertices=4,
        radius1=0.34,
        radius2=0.01,
        depth=0.58,
        location=(0.0, 0.0, 1.32),
        rotation=(0.0, 0.0, math.radians(45.0)),
    )
    tip = bpy.context.active_object
    tip.scale = (1.0, 0.25, 1.0)
    assign_mat(tip, plasma_glow)
    objs.append(tip)

    # Metallic Spine along Center of Blade
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0.0, 0.0, 0.15))
    spine = bpy.context.active_object
    spine.scale = (0.10, 0.09, 0.65)
    assign_mat(spine, hilt_metal)
    objs.append(spine)

    parent_and_rotate(objs, angle_deg=-38.0, offset=(0.0, 0.0, 0.15))


def build_laser_rifle():
    """Laser Rifle: Futuristic ranged pulse rifle with glowing emerald energy coils and scope."""
    body_metal = create_toon_material(
        "RifleBody", (0.12, 0.18, 0.24), (0.26, 0.36, 0.46), (0.48, 0.62, 0.76)
    )
    stock_dark = create_toon_material(
        "RifleDark", (0.05, 0.07, 0.10), (0.12, 0.15, 0.20), (0.22, 0.28, 0.36)
    )
    laser_green = create_toon_material(
        "RifleLaser", (0.0, 0.62, 0.22), (0.12, 0.95, 0.42), (0.62, 1.0, 0.78), emission_strength=1.5
    )
    amber_lens = create_toon_material(
        "RifleAmber", (0.58, 0.24, 0.0), (0.96, 0.58, 0.05), (1.0, 0.86, 0.32), emission_strength=1.3
    )

    objs = []

    # Main Receiver Body
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(-0.10, 0.0, 0.12))
    receiver = bpy.context.active_object
    receiver.scale = (0.62, 0.16, 0.20)
    add_bevel(receiver, 0.04)
    assign_mat(receiver, body_metal)
    objs.append(receiver)

    # Tactical Shoulder Stock (Connected to back of receiver)
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(-0.98, 0.0, 0.04))
    stock = bpy.context.active_object
    stock.scale = (0.34, 0.13, 0.18)
    add_bevel(stock, 0.03)
    assign_mat(stock, stock_dark)
    objs.append(stock)

    # Pistol Grip (Connected to bottom of receiver)
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(-0.38, 0.0, -0.22))
    grip = bpy.context.active_object
    grip.scale = (0.11, 0.11, 0.24)
    grip.rotation_euler = (0.0, math.radians(20.0), 0.0)
    assign_mat(grip, stock_dark)
    objs.append(grip)

    # Glowing Energy Magazine Cell (Connected to bottom-front of receiver)
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0.16, 0.0, -0.22))
    mag = bpy.context.active_object
    mag.scale = (0.13, 0.12, 0.24)
    mag.rotation_euler = (0.0, math.radians(-14.0), 0.0)
    assign_mat(mag, laser_green)
    objs.append(mag)

    # Forward Barrel Shroud (Connected to front of receiver)
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0.82, 0.0, 0.14))
    shroud = bpy.context.active_object
    shroud.scale = (0.44, 0.13, 0.15)
    add_bevel(shroud, 0.03)
    assign_mat(shroud, body_metal)
    objs.append(shroud)

    # Glowing Plasma Coils along Barrel
    for x_pos in (0.56, 0.82, 1.08):
        bpy.ops.mesh.primitive_cube_add(size=2.0, location=(x_pos, 0.0, 0.14))
        coil = bpy.context.active_object
        coil.scale = (0.05, 0.16, 0.17)
        assign_mat(coil, laser_green)
        objs.append(coil)

    # Precision Muzzle & Emitter Tip (Connected to front of shroud)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=10,
        radius=0.08,
        depth=0.45,
        location=(1.42, 0.0, 0.14),
        rotation=(0.0, math.radians(90.0), 0.0),
    )
    barrel = bpy.context.active_object
    assign_mat(barrel, stock_dark)
    objs.append(barrel)

    bpy.ops.mesh.primitive_cylinder_add(
        vertices=10,
        radius=0.11,
        depth=0.16,
        location=(1.66, 0.0, 0.14),
        rotation=(0.0, math.radians(90.0), 0.0),
    )
    muzzle = bpy.context.active_object
    assign_mat(muzzle, laser_green)
    objs.append(muzzle)

    # Scope Mounts + Holographic Sniper Optic Scope on Top Rail
    for mount_x in (-0.24, 0.12):
        bpy.ops.mesh.primitive_cube_add(size=2.0, location=(mount_x, 0.0, 0.34))
        mount = bpy.context.active_object
        mount.scale = (0.06, 0.08, 0.10)
        assign_mat(mount, stock_dark)
        objs.append(mount)

    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12,
        radius=0.12,
        depth=0.64,
        location=(-0.06, 0.0, 0.46),
        rotation=(0.0, math.radians(90.0), 0.0),
    )
    scope = bpy.context.active_object
    assign_mat(scope, stock_dark)
    objs.append(scope)

    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12,
        radius=0.10,
        depth=0.68,
        location=(-0.06, 0.0, 0.46),
        rotation=(0.0, math.radians(90.0), 0.0),
    )
    lens = bpy.context.active_object
    assign_mat(lens, amber_lens)
    objs.append(lens)

    parent_and_rotate(objs, angle_deg=-28.0, offset=(-0.05, 0.0, 0.12))


def build_void_staff():
    """Void Staff: Ornate magic staff with crescent crown and floating violet void crystal."""
    shaft_obsidian = create_toon_material(
        "StaffShaft", (0.12, 0.06, 0.24), (0.26, 0.14, 0.46), (0.46, 0.28, 0.72)
    )
    crown_gold = create_toon_material(
        "StaffGold", (0.45, 0.28, 0.06), (0.86, 0.60, 0.14), (1.0, 0.86, 0.36)
    )
    void_violet = create_toon_material(
        "StaffVoid", (0.58, 0.06, 0.78), (0.94, 0.22, 1.0), (1.0, 0.68, 1.0), emission_strength=1.5
    )

    objs = []

    # Main Staff Shaft
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.10, depth=2.35, location=(0.0, 0.0, -0.35))
    shaft = bpy.context.active_object
    assign_mat(shaft, shaft_obsidian)
    objs.append(shaft)

    # Bottom Spike Ferrule
    bpy.ops.mesh.primitive_cone_add(
        vertices=8,
        radius1=0.14,
        radius2=0.01,
        depth=0.38,
        location=(0.0, 0.0, -1.62),
        rotation=(math.radians(180.0), 0.0, 0.0),
    )
    ferrule = bpy.context.active_object
    assign_mat(ferrule, crown_gold)
    objs.append(ferrule)

    # Golden Ring Collars along Shaft
    for z_pos in (-0.95, -0.15, 0.55):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.15, minor_radius=0.045, location=(0.0, 0.0, z_pos)
        )
        ring = bpy.context.active_object
        assign_mat(ring, crown_gold)
        objs.append(ring)

    # Ornate Crescent Horns at Top of Staff
    for side in (-1, 1):
        bpy.ops.mesh.primitive_cone_add(
            vertices=8,
            radius1=0.18,
            radius2=0.02,
            depth=0.95,
            location=(side * 0.36, 0.0, 1.05),
            rotation=(0.0, side * math.radians(-22.0), 0.0),
        )
        horn = bpy.context.active_object
        assign_mat(horn, crown_gold)
        objs.append(horn)

        bpy.ops.mesh.primitive_cube_add(size=2.0, location=(side * 0.20, 0.0, 0.72))
        base_wing = bpy.context.active_object
        base_wing.scale = (0.16, 0.08, 0.10)
        base_wing.rotation_euler = (0.0, side * math.radians(32.0), 0.0)
        assign_mat(base_wing, crown_gold)
        objs.append(base_wing)

    # Floating Void Crystal Orb inside Crescent Crown
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.28, location=(0.0, 0.0, 1.12))
    orb = bpy.context.active_object
    orb.scale = (0.85, 0.85, 1.25)
    assign_mat(orb, void_violet)
    objs.append(orb)

    # Energy Halo around Void Orb
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.44,
        minor_radius=0.032,
        location=(0.0, 0.0, 1.12),
        rotation=(math.radians(72.0), 0.0, 0.0),
    )
    halo = bpy.context.active_object
    assign_mat(halo, void_violet)
    objs.append(halo)

    parent_and_rotate(objs, angle_deg=-36.0, offset=(0.0, 0.0, 0.18))


def render_asset(filename, builder_fn):
    clear_scene()
    scene, _ = setup_render_and_camera()
    builder_fn()
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    out_path = os.path.join(OUTPUT_DIR, filename)
    scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print(f"[ARSENAL] Rendered sprite: {out_path}")


def main():
    assets = [
        ("cyber_knight.png", build_cyber_knight),
        ("shadow_ranger.png", build_shadow_ranger),
        ("arcane_mage.png", build_arcane_mage),
        ("plasma_blade.png", build_plasma_blade),
        ("laser_rifle.png", build_laser_rifle),
        ("void_staff.png", build_void_staff),
    ]
    for filename, builder in assets:
        render_asset(filename, builder)


if __name__ == "__main__":
    main()
