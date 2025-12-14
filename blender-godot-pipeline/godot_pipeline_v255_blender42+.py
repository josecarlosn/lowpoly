bl_info = {
    "name": "Godot Pipeline",
    "description": "A 3D pipeline for exporting from Blender and importing into Godot 4+.",
    "author": "Michael Jared",
    "version": (2,5,5),
    "location": "View3D > Properties > Godot Pipeline",
    "doc_url": "https://www.michaeljared.ca",
    "blender": (2, 80, 0),
    "category": "Object"
}

import bpy, math
from mathutils import Vector
from bpy.app.handlers import persistent

from bpy.types import (
            Operator, 
            PropertyGroup, 
            Panel
        )
from bpy.props import (
            IntProperty,
            EnumProperty,
            BoolProperty,
            FloatProperty,
            StringProperty,
            PointerProperty,
            CollectionProperty
        )

# global access for global props ... this is probably bad

global_props = 0

def update_global_props(props):
    global global_props
    global_props = props

# this is a full list of pipeline customs - helps with displaying and clearing data
custom_list = ["collision", "size_x", "size_y", "size_z", "height", "radius", "script",\
    "material_0", "material_1", "material_2", "material_3", "shader", "nav_mesh", "multimesh",\
    "prop_file", "name_override", "physics_mat", "state", "prop_string", "packed_scene", "center_x", "center_y", "center_z"]

### QUICK DROPDOWN for PATH SETTER

default_list = [["(none)", "(none)"], ["(clear recent)", "(clear recent)"]]

# path collection name
col_name = "GodotScriptPaths"

def enum_items_generator(self, context):
    global col_name
    temp_paths = []
    
    path_type = context.scene.GodotPipelineProps.path_options
    
    # collection
    if col_name in bpy.data.collections:
        c = bpy.data.collections[col_name]
        
        if path_type in c:
            for x in c[path_type]:
                temp_paths.append([x, "Godot filepath"])
    else:
        temp_paths = default_list

    enum_items = []
    
    for e, d in enumerate(temp_paths):
        enum_items.append((d[0], d[0], str(d[1]), e))
    
    return enum_items

def script_dropdown_update(self, context):
    global col_name
    
    v = context.scene.GodotPipelineProps.script_dropdown
    
    if v == "(none)":
        pass
        # context.scene.GodotPipelineProps.set_path = ""
    elif v == "(clear recent)":
        if col_name in bpy.data.collections:
            c = bpy.data.collections[col_name]
            path_type = context.scene.GodotPipelineProps.path_options
            
            if path_type in c:
                del c[path_type]
            
    else:
        context.scene.GodotPipelineProps.set_path = v

def script_dropdown_update2(self, context):
    v = context.scene.GodotPipelineProps.script_param_dropdown
    
    if v == "(none)":
        context.scene.GodotPipelineProps.prop_path = ""
    elif v == "(clear recent)":
        col_name = "GodotScriptPaths"
        if col_name in bpy.data.collections:
            bpy.data.collections.remove(bpy.data.collections[col_name])
    else:
        context.scene.GodotPipelineProps.prop_path = v

### PANEL, GLOBAL PROPS
class GodotPipelineProperties(PropertyGroup):
    ## GLOBAL
    counter : IntProperty(name = "Counter for Export", default = 0)
    global_UI : BoolProperty(name = "Utilities", default = False)
    mesh_data : BoolProperty(name = "Assign to Mesh", default = False, description = "By checking this option, all the custom data will be assigned to the mesh and not the object. This works great for instancing objects")
    use_mat_slot : BoolProperty(name = "Use Material Slot", default = True, description = "Automatically try to set the material path name based on the material slot name in Blender, if the slot includes res://")
    object_name : StringProperty(name = "Name Override", default = "", description = "Type in any name here to override the node name in Godot. Hit 'Apply Name Override' to apply it")
   
    ## COLLISION
    collision_UI : BoolProperty(name = "Collisions", default=False)
    collision_margin : FloatProperty(name = 'Collision Margin', default = 1.00, description="Increase this number to increase the size of the collision (e.g. 1.05 means increase size by 5%)")
    apply_scale : BoolProperty(name = "Apply Scale", default=True, description="Unless you have a very good reason, this should be left on.")
    preserve_origin : BoolProperty(name = "Preserve Origin", default=True, description="Unchecking this causes the addon to move the mesh's origin to the center of its bounding box. Usually best to leave this on.")
    col_types : EnumProperty(
        name =  "Collision",
        items = (
            ("BOX", "Box", ""),
            ("CYLINDER", "Cylinder", ""),
            ("SPHERE", "Sphere", ""),
            ("CAPSULE", "Capsule", ""),
            ("TRIMESH", "Trimesh (Concave)", ""),
            ("SIMPLE", "Simple (Convex)", ""),
            ("BODYONLY", "None", "")
        ),
        default = "BOX", description="This is the CollisionShape3D that gets used"
    )
    body_types : EnumProperty(
        name = "Body",
        items = (
            ("STATIC", "Static Body 3D", ""),
            ("RIGID", "Rigid Body 3D", ""),
            ("AREA", "Area 3D", ""),
            ("ANIMATABLE", "Animatable Body 3D", ""),
            ("CHARACTER", "Character Body 3D", ""),
            ("COLONLY", "None", "")
        ),
        default = "STATIC", description="This is the PhysicsBody3D that gets used"
    )
    display_wire: BoolProperty(name = "Display Wireframe Bounds", default = False, description="Changes the display of the object to wireframe in Blender. Has no effect in Godot")
    discard_mesh: BoolProperty(name = "Discard Mesh", default = False, description="Discards the mesh associated with the node in Godot. This is useful if you want to only import collision shapes")
    
    ## SET PATHS
    path_UI : BoolProperty(name = "Path Setter", default = False)
    script_dropdown: EnumProperty(items = enum_items_generator, name = "Recent Paths", default=None, update=script_dropdown_update)
    set_path : StringProperty(name = "Set Path", default = "", description = "This is the res:// path from Godot")
    path_options : EnumProperty(
        name = "Path Type",
        items = (
            ("script", "Script", ".gd script file"),
            ("material_0", "Material 0", ".tres material for slot 0"),
            ("material_1", "Material 1", ".tres material for slot 1"),
            ("material_2", "Material 2", ".tres material for slot 2"),
            ("material_3", "Material 3", ".tres material for slot 3"),
            ("shader", "Shader", ".gdshader shader file"),
            ("nav_mesh", "Nav Mesh", ".tres file to save mesh resource"),
            ("multimesh", "Multimesh", ".tres file to save mesh resource"),
            ("physics_mat", "Physics Material", ".tres file physics material"),
            ("prop_file", "Parameter File", ".txt file for injecting Node parameters"),
            ("packed_scene", "Packed Scene", "instantiate a .tscn packed scene in Godot")
        ),
        default = "script"
    )
    
    ## STRING SETTER
    string_options : EnumProperty(
        name =  "String Type",
        items = (
            ("prop_string", "Property String", "Set parsable GDscript instructions semicolon delimited"),
        ),
        default = "prop_string"
    )
    string_setter_UI : BoolProperty(name = "String Setter", default = False)
    string_setter_string : StringProperty(name = "String", default = "", description = "Set other string options")
    
    # SAVE
    export_UI : BoolProperty(name = "Export", default = False)
    use_object_suffix : BoolProperty(name = "Append Object Name", default = False, description="Append '_ObjectName.gltf' to the GLTF filename")
    apply_mods : BoolProperty(name = "Apply Modifiers", default = True)
    export_textures : BoolProperty(name = "Export Textures", default = True, description="Turn this off to save time, if all your images (textures) are already loaded on the Godot side.")
    save_path : StringProperty(name = "", default="", maxlen=1024, subtype='FILE_PATH', description="Set up the .gltf file path for BLENDER to use. This is not a res:// file name. On Windows, the filepath would be something like C:\\...\\my_level.gltf")
    use_NLA : BoolProperty(name = "Use NLA Tracks", default = False)
    individual_origins : BoolProperty(name = "Individual Origins", default = False)
    packed_resources : BoolProperty(name = "Individual Packed Resources", default = False)

class GodotPipelinePanel(bpy.types.Panel):
    bl_idname = "OBJECT_PT_godot_pipeline"
    bl_label = "Godot Pipeline"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_context = "objectmode"
    bl_category = "Godot Pipeline"

    def draw(self, context):
        layout = self.layout
        scene = context.scene
        props = scene.GodotPipelineProps
        obj = context.object
        
        update_global_props(props)
        
        # GLOBAL SETTINGS
        box = layout.box()
        row = box.row()
        row.prop(props, "global_UI",
            icon="TRIA_DOWN" if props.global_UI else "TRIA_RIGHT",
            icon_only=False, emboss=False
        )
        
        if props.global_UI:
            row = box.row()
            row.prop(props, "mesh_data")
        
            row = box.row()
            row.prop(props, "use_mat_slot")
        
            row = box.split(factor=0.4)
            row.label(text='Name Override:')
            row.prop(props, "object_name", text='')
            
            row = box.row()
            row.operator("object.b2g_name_override", icon='NONE', text="Apply Name Override")
            
            row = box.row()
            row.operator("object.b2g_toggle_skip", icon='NONE', text="Toggle Skip")
            
            box.separator()
            
            row = box.row()
            row.operator("object.b2g_show_all_customs", icon='NONE', text="Display Addon Data")
            
            row = box.row()
            row.operator("object.b2g_clear_all_customs", icon='NONE', text="Clear Addon Data")
            
        # COLLISIONS
        box = layout.box()
        row = box.row()
        row.prop(props, "collision_UI",
            icon="TRIA_DOWN" if props.collision_UI else "TRIA_RIGHT",
            icon_only=False, emboss=False
        )
        
        if props.collision_UI:
            row = box.row()
            row.prop(props, "col_types")
            
            row = box.row()
            row.prop(props, "body_types")
            
            row = box.row()
            row.prop(props, "display_wire")
            
            row = box.row()
            row.prop(props, "discard_mesh")
            
            row = box.row()
            row.prop(props, "collision_margin")
            
            row = box.row()
            row.prop(props, "apply_scale")
            
            row = box.row()
            row.prop(props, "preserve_origin")
            
            row = box.row()
            row.operator("object.b2g_set_collisions", icon='NONE', text="Set Collisions")
            
        
        # PATH SETTER
        box = layout.box()
        row = box.row()
        row.prop(props, "path_UI",
            icon="TRIA_DOWN" if props.path_UI else "TRIA_RIGHT",
            icon_only=False, emboss=False
        )
        
        if props.path_UI:
            row = box.split(factor=0.15)
            row.label(text="Path:")
            row = row.split(factor=0.15)
            row.prop(props, "script_dropdown", icon="FILE_FOLDER", icon_only=True)
            row.prop(props, "set_path", text="")
            
            row = box.row()
            row.prop(props, "path_options")
            
            row = box.row()
            row.operator("object.b2g_set_path", icon='NONE', text="Set Path")
        
        # STRING SETTER
        box = layout.box()
        row = box.row()
        row.prop(props, "string_setter_UI",
            icon="TRIA_DOWN" if props.string_setter_UI else "TRIA_RIGHT",
            icon_only=False, emboss=False
        )
        
        if props.string_setter_UI:
            row = box.row()
            row.prop(props, "string_options", icon="NONE")
            row = box.row()
            row.prop(props, "string_setter_string")
            row = box.row()
            row.operator("object.b2g_set_string", icon='NONE', text="Set String")
        
        # EXPORT
        box = layout.box()
        
        row = box.row()
        row.prop(props, "export_UI",
            icon="TRIA_DOWN" if props.export_UI else "TRIA_RIGHT",
            icon_only=False, emboss=False
        )
        
        if props.export_UI:
            row = box.row()
            row.prop(props, "save_path")
            
            row = box.row()
            row.prop(props, "apply_mods")
            
            row = box.row()
            row.prop(props, "use_NLA")
            
            row = box.row()
            row.prop(props, "export_textures")
            
            row = box.row()
            row.prop(props, "use_object_suffix")
            
            row = box.row()
            row.prop(props, "individual_origins")
            
            row = box.row()
            row.prop(props, "packed_resources")
            
            row = box.row()
            row.operator("object.b2g_godot_export", icon='NONE', text="Export for Godot")
        ###


### CORE ADDON CLASSES

class SetCollisions(bpy.types.Operator):
    """Set Collisions"""
    bl_idname = "object.b2g_set_collisions"
    bl_label = "Set Collision Type"
    bl_options = {'REGISTER', 'UNDO'}
    
    clear_fields = ["radius", "height", "size_x", "size_y", "size_z"]
    
    # for these types we will automatically reset bounding box and origin
    shape_fields = ["BOX", "CYLINDER", "SPHERE", "CAPSULE"]

    def execute(self, context):
        scene = context.scene
        props = scene.GodotPipelineProps
        
        
        # compose collision string
        
        col_string = props.col_types.lower()
        if props.col_types == "BODYONLY":
            col_string = "bodyonly"
        if props.body_types == "STATIC":
            col_string += ""
        if props.body_types == "RIGID":
            col_string += "-r"
        if props.body_types == "AREA":
            col_string += "-a"
        if props.body_types == "ANIMATABLE":
            col_string += "-m"
        if props.body_types == "COLONLY":
            col_string += "-c"
        if props.body_types == "CHARACTER":
            col_string += "-h"
        
        if props.discard_mesh:
            col_string += "-d"
        
        contains_linked_dupes = False
        meshes = []
        for obj in context.selected_objects:
            meshes.append(obj.data)
        
        # find any un-selected meshes that are linked to the selected objects
        for obj in bpy.data.objects:
            # skip over selected objects
            if obj in context.selected_objects: continue
            
            if obj.data in meshes:
                contains_linked_dupes = True
                break
        
        if props.apply_scale:
            if contains_linked_dupes:
                ShowMessageBox('The "Apply Scale" option does not work with Linked Duplicates.', title = "Apply Scale", icon = 'INFO')
            else:
                bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        
        for obj in context.selected_objects:
            if props.display_wire:
                obj.display_type = "BOUNDS"
            else:
                obj.display_type = "TEXTURED"
            
            # apply data to mesh, not object
            if props.mesh_data: obj = obj.data
            
            if props.object_name != "":
                obj["name_override"] = props.object_name
            
            if "collision" in obj:
                del obj["collision"]
            
            obj["collision"] = col_string

            # clear existing fields
            for field in self.clear_fields:
                if field in obj:
                    del obj[field]
            
        # reset origin to bounding box and set collision sizes
        if props.col_types in self.shape_fields:
            bpy.ops.object.b2g_reset_origin_bb()
            bpy.ops.object.b2g_set_collision_size()

        return {'FINISHED'}

def strip_col_fields(value):
    return value.replace("-r", "").replace("-a", "").replace("-m", "").replace("-c", "").replace("-h", "").replace("-d", "")

class SetCollisionSize(bpy.types.Operator):
    """Set Collision Size Script"""
    bl_idname = "object.b2g_set_collision_size"
    bl_label = "Set Collision Size"
    bl_options = {'REGISTER', 'UNDO'}

    def set_size(self, obj, dim_obj, margin):

        if "collision" in obj:
            value = obj["collision"]
            # clear all flags to check collision shape
            value = strip_col_fields(value)
            if value == "box":
                # divide out by scale, because the collision object in godot is parented to the actual mesh,
                # so it will get the parent's scale (basically we are preventing the scale from being applied twice)
                obj["size_x"] = str(round(margin * dim_obj.dimensions[0] / dim_obj.scale[0], 4))
                obj["size_z"] = str(round(margin * dim_obj.dimensions[1] / dim_obj.scale[1], 4))
                obj["size_y"] = str(round(margin * dim_obj.dimensions[2] / dim_obj.scale[2], 4))
            
            if value == "cylinder" or value == "capsule":
                obj["height"] = str(round(margin * dim_obj.dimensions[2] / dim_obj.scale[2], 4))
                
                # radius is calculated in x, y plane
                # take larger value
                r = 0.5 * dim_obj.dimensions[0] / dim_obj.scale[0]
                if dim_obj.dimensions[1] > dim_obj.dimensions[0]:
                    r = 0.5 * dim_obj.dimensions[1] / dim_obj.scale[1]
                
                obj["radius"] = str(round(margin * r, 4))
            
            if value == "sphere":
                # radius is taken to be largest of x,y,z side lengths
                r = 0.5 * dim_obj.dimensions[0] / dim_obj.scale[0]
                
                if dim_obj.dimensions[1] > dim_obj.dimensions[0]:
                    r = 0.5 * dim_obj.dimensions[1] / dim_obj.scale[1]
                    
                if dim_obj.dimensions[2] > dim_obj.dimensions[0]:
                    r = 0.5 * dim_obj.dimensions[2] / dim_obj.scale[2]
                
                obj["radius"] = str(round(margin * r, 4))
    
    def execute(self, context):
        scene = context.scene
        props = scene.GodotPipelineProps
        
        margin = props.collision_margin
        
        for obj in context.selected_objects:
            dim_obj = obj
            if props.mesh_data: obj = obj.data
            self.set_size(obj, dim_obj, margin)
        
        return {'FINISHED'}

class ResetOriginBB(bpy.types.Operator):
    """Reset Origin Bounding Box"""
    bl_idname = "object.b2g_reset_origin_bb"
    bl_label = "Reset Origin Bounding Box"
    bl_options = {'REGISTER', 'UNDO'}

    def execute(self, context):
        scene = context.scene
        props = scene.GodotPipelineProps
        
        
        if props.preserve_origin:
            
            for obj in context.selected_objects:
                
                fp = True # first pass
                min_x = 0
                min_y = 0
                min_z = 0
                
                max_x = 0
                max_y = 0
                max_z = 0
                
                # convert to world bounding box - this effectively encodes the rotation
                bound_box_vertices = [Vector(v) for v in obj.bound_box]
                world_mat = obj.matrix_world
                world_bound_box = [world_mat @ v for v in bound_box_vertices]
                
                for v in world_bound_box:
                    # subtract off the location - this assumes scale was applied to the model
                    v = v - obj.location
                    if v[0] > max_x or fp: max_x = v[0]
                    if v[1] > max_y or fp: max_y = v[1]
                    if v[2] > max_z or fp: max_z = v[2]
                    
                    if v[0] < min_x or fp: min_x = v[0]
                    if v[1] < min_y or fp: min_y = v[1]
                    if v[2] < min_z or fp: min_z = v[2]
                    fp = False
                
                center_x = (min_x + max_x) / 2
                center_y = (min_y + max_y) / 2
                center_z = (min_z + max_z) / 2
                
                obj["center_x"] = center_x
                obj["center_z"] = center_y
                obj["center_y"] = center_z
            
        else:
            bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
            for obj in context.selected_objects:
                if "center_x" in obj: del obj["center_x"]
                if "center_y" in obj: del obj["center_y"]
                if "center_z" in obj: del obj["center_z"]
        
        return {'FINISHED'}


class SetPath(bpy.types.Operator):
    """Set Path"""
    bl_idname = "object.b2g_set_path"
    bl_label = "Set Path"
    bl_options = {'REGISTER', 'UNDO'}

    def execute(self, context):
        global col_name
        
        scene = context.scene
        props = scene.GodotPipelineProps
        
        new_path = props.set_path
        
        for obj in context.selected_objects:
            if props.mesh_data: obj = obj.data
            if props.object_name != "":
                obj["name_override"] = props.object_name
            
            obj[props.path_options] = new_path
        
        last_path = props.set_path
        
        if "res://" in last_path:
            
            # create new collection if it does not exist
            if col_name in bpy.data.collections:
                c = bpy.data.collections[col_name]
            else:
                c = bpy.data.collections.new(col_name)
                c.use_fake_user = True
            
            path_type = props.path_options
            
            # create the dictionary
            if path_type not in c:
                c[path_type] = {}
                for x in default_list:
                    c[path_type][x[0]] = 1
                    
            c[path_type][last_path] = 1
        
        props.script_dropdown = "(none)"
        
        return {'FINISHED'}

class SetString(bpy.types.Operator):
    """Set String"""
    bl_idname = "object.b2g_set_string"
    bl_label = "Set String"
    bl_options = {'REGISTER', 'UNDO'}

    def execute(self, context):
        scene = context.scene
        props = scene.GodotPipelineProps
        
        new_path = props.set_path
        
        for obj in context.selected_objects:
            if props.mesh_data: obj = obj.data
            if props.object_name != "":
                obj["name_override"] = props.object_name
            
            obj[props.string_options] = props.string_setter_string
        
        return {'FINISHED'}

class ClearAllCustoms(bpy.types.Operator):
    """Clear All Customs"""
    bl_idname = "object.b2g_clear_all_customs"
    bl_label = "Clear All Customs"
    bl_options = {'REGISTER', 'UNDO'}

    def execute(self, context):
        scene = context.scene
        props = scene.GodotPipelineProps
        
        for obj in context.selected_objects:
            if props.mesh_data: obj = obj.data
            
            clear_list = []
            for key, value in obj.items():
                if key in custom_list:
                    clear_list.append(key)
            
            for key in clear_list:
                del obj[key]
        
        return {'FINISHED'}


class NameOverride(bpy.types.Operator):
    """Name Override"""
    bl_idname = "object.b2g_name_override"
    bl_label = "Name Override"
    bl_options = {'REGISTER', 'UNDO'}

    def execute(self, context):
        scene = context.scene
        props = scene.GodotPipelineProps
        
        for obj in context.selected_objects:
            if props.mesh_data: obj = obj.data
            if props.object_name != "":
                obj["name_override"] = props.object_name
            else:
                if "name_override" in obj:
                    del obj["name_override"]
            
            props.object_name = ""
        
        return {'FINISHED'}


class ToggleSkip(bpy.types.Operator):
    """Toggle Skip"""
    bl_idname = "object.b2g_toggle_skip"
    bl_label = "Name Override"
    bl_options = {'REGISTER', 'UNDO'}

    def execute(self, context):
        scene = context.scene
        props = scene.GodotPipelineProps
        
        for obj in context.selected_objects:
            
            state = ""
            if "state" in obj:
                state = obj["state"]
            
            if state == "":
                obj["state"] = "skip"
            else:
                obj["state"] = ""
        
        return {'FINISHED'}


### FINAL RUN (on save) and EXPORT

expc = "export_counter"
def final_run():
    props = global_props
    if props == 0: return

    # this is kind of a hack that kicks the Godot importer
    props.counter += 1
    if props.counter >= 100: props.counter = 0
    
    for obj in bpy.data.objects:
    
        # set material slots that have res:// in the name    
        if props.use_mat_slot:
            i = 0
            for slot in obj.material_slots:
                if "res://" in slot.name:
                    if props.mesh_data:
                        obj.data["material_" + str(i)] = slot.name
                    else:
                        obj["material_" + str(i)] = slot.name
                i += 1

@persistent
def final_run_persistent(dummy):
    final_run()

class GodotExport(bpy.types.Operator):
    """Godot Export"""
    bl_idname = "object.b2g_godot_export"
    bl_label = "Godot Export"
    bl_options = {'REGISTER', 'UNDO'}
    
    def execute(self, context):
        scene = context.scene
        props = scene.GodotPipelineProps
        
        final_run()
        
        if '.gltf' not in props.save_path:
            ShowMessageBox('The path must contain .gltf', title = "Export: Path Error", icon = 'INFO')
            return {'FINISHED'}
        
        temp_save_path = props.save_path
        
        if props.use_object_suffix and context.active_object:
            temp_save_path = temp_save_path.replace(".gltf", "_" + context.active_object.name + ".gltf")
        
        exp_textures = "AUTO"
        if not props.export_textures: exp_textures = "NONE"
        
        anim_mode = 'ACTIONS'
        if props.use_NLA: anim_mode = 'NLA_TRACKS'
        
        bpy.ops.export_scene.gltf(filepath=bpy.path.abspath(temp_save_path), export_format='GLTF_SEPARATE', \
            export_extras=True, use_visible=True, export_apply=props.apply_mods, export_image_format=exp_textures, \
            export_animation_mode=anim_mode)
        return {'FINISHED'}
    
### INFO BOX (Display Addon Data)

class ShowAllCustoms(bpy.types.Operator):
    """Show All Customs"""
    bl_idname = "object.b2g_show_all_customs"
    bl_label = "Show All Customs"
    bl_options = {'REGISTER', 'UNDO'}

    def execute(self, context):
        scene = context.scene
        props = scene.GodotPipelineProps
        
        obj = context.active_object
        
        obj_str = "Assigned to OBJECT"
        if props.mesh_data: obj_str = "Assigned to MESH"
        
        ShowCustoms(obj, obj.name + " Customs ("+obj_str+")")
        
        return {'FINISHED'}

def ShowCustoms(obj, title = "Message Box", icon = 'INFO'):

    def draw(self, context):
        scene = context.scene
        props = scene.GodotPipelineProps
        
        objx = obj
        object_found = False
        
        #if "items" not in objx: return
        
        for key, value in objx.items():
            if key in custom_list:
                object_found = True
                break
        
        if object_found:
            self.layout.label(text="Object Customs:")
            for key, value in objx.items():
                if key in custom_list:
                    self.layout.label(text=str(key)+"="+str(value))
        
        if hasattr(obj, "data"):
            objx = obj.data
            mesh_found = False
            
            if hasattr(objx, "items"):
                for key, value in objx.items():
                    if key in custom_list:
                        mesh_found = True
                        break
                
                if mesh_found:
                    self.layout.label(text="")
                    self.layout.label(text="Mesh Data Customs:")
                    
                    for key, value in objx.items():
                        if key in custom_list:
                            self.layout.label(text=str(key)+"="+str(value))

    bpy.context.window_manager.popup_menu(draw, title = title, icon = icon)

def ShowMessageBox(message = "", title = "Message Box", icon = 'INFO'):

    def draw(self, context):
        self.layout.label(text=message)

    bpy.context.window_manager.popup_menu(draw, title = title, icon = icon)

### UPDATE LOGIC

path_options = ["script", "material_0", "material_1", "material_2", "material_3", "shader", "nav_mesh", "multimesh", "physics_mat", "prop_file", "packed_scene"]
def msgbus_callback(*arg):
    global path_options
    
    scene = bpy.context.scene
    props = scene.GodotPipelineProps
    
    mesh_data_found = False
    for obj in bpy.context.selected_objects:
        for c in custom_list:
            objx = obj
            if obj.type != "EMPTY":
                if hasattr(obj, "data") and c in obj.data:
                    mesh_data_found = True
                    objx = obj.data
            
            if c in objx:
                v = objx[c]
                if c == "collision":
                    base_col = strip_col_fields(v)
                    body = "STATIC"
                    if "-r" in v: body = "RIGID"
                    elif "-a" in v: body = "AREA"
                    elif "-m" in v: body = "ANIMATABLE"
                    elif "-h" in v: body = "CHARACTER"
                    elif "-c" in v: body = "COLONLY"
                    
                    if "-d" in v: props.discard_mesh = True
                    else: props.discard_mesh = False
                    
                    props.col_types = str(base_col).upper()
                    props.body_types = body
                
                if c in path_options:
                    props.path_options = c
                    props.set_path = v
    
    props.mesh_data = mesh_data_found
        
owner = object()

def subscribe_active_obj(): 
    bpy.msgbus.subscribe_rna(
        key=(bpy.types.LayerObjects, 'active'),
        owner=owner,
        args=(1,2,3),
        notify=msgbus_callback,
        options={'PERSISTENT', }
        )

@persistent
def load_handler(dummy):
    subscribe_active_obj()

### ADDON REGISTRATION

classes = [GodotPipelineProperties, GodotPipelinePanel,\
    SetCollisions, SetCollisionSize, ResetOriginBB, SetPath, ClearAllCustoms,\
    ShowAllCustoms, NameOverride, ToggleSkip, SetString, \
    GodotExport]

def register():
    for cls in classes:
        bpy.utils.register_class(cls)

    bpy.types.Scene.GodotPipelineProps = PointerProperty(type = GodotPipelineProperties)
    
    subscribe_active_obj()
    if load_handler not in bpy.app.handlers.load_post:
        bpy.app.handlers.load_post.append(load_handler)
    
    # 2025-09-27 removing this feature because I think it causes instability
    # it was only here to assist support .blend file exporting
    #if final_run_persistent not in bpy.app.handlers.save_pre:
    #    bpy.app.handlers.save_pre.append(final_run_persistent)
        
    

def unregister():
    for cls in classes:
        bpy.utils.unregister_class(cls)
        
    #if final_run_persistent in bpy.app.handlers.save_pre:
    #    bpy.app.handlers.save_pre.remove(final_run_persistent)
    
    if load_handler in bpy.app.handlers.load_post:
        bpy.app.handlers.load_post.remove(load_handler)
        
    if owner is not None:
        bpy.msgbus.clear_by_owner(owner)

if __name__ == "__main__":
    register()