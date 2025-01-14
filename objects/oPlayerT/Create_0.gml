// Setup
mask_index = sPlayerMask;

// Declare methods
event_user(15);

// Sprite management
sprites = {};
init_sprites(
	"idle", "Idle",
	"run",	"Run",
	"jump",	"Jump",
	"fall",	"Fall",
	"groundAttack1", "Attack1",
	"groundAttack2", "Attack2",
	"groundAttack3", "Attack3",
	"airAttack1", "AirAttack1",
	"airAttack2", "AirAttack2",
	"throwSword", "ThrowSword"
);

effectSprites = {};
init_effect_sprites(
	"groundAttack1", "Attack1",
	"groundAttack2", "Attack2",
	"groundAttack3", "Attack3",
	"airAttack1", "AirAttack1",
	"airAttack2", "AirAttack2"
);

// Variables
spd = 3;
hspd = 0;
vspd = 0;
vspdMax = 15;

jspd = 12;
gravGround = .6;	// Normal gravity
gravAttack = .05;	// Low gravity when air attacking
grav = gravGround;

face = 1;
hasSword = 1;
coyoteDuration = 8;
nextAttack = false;
canAirAttack = true;

// Input
input = {};
check_input();

// State Machine
fsm = new SnowState("idle");

fsm
	.history_enable()
	.history_set_max_size(20)
	.event_set_default_function("draw", function() {
		// Draw this no matter what state we are in
		// (Unless it is overridden, ofcourse)
		draw_sprite_ext(sprite_index, image_index, x, y, face * image_xscale, image_yscale, image_angle, image_blend, image_alpha);
	})
	.add("idle", {
		enter: function() {
			sprite_index = get_sprite();
			image_speed = 1;
			
			hspd = 0;
			vspd = 0;
		},
		step: function() {
			recall_sword();
			apply_gravity();
			move_and_collide();
		}
	})
	.add("run", {
		enter: function() {
			sprite_index = get_sprite();
			image_speed = 1;
		},
		step: function() {
			set_movement();
			recall_sword();
			apply_gravity();
			move_and_collide();
		}
	})
	.add("jump", {
		enter: function() {
			sprite_index = get_sprite();
			image_index = 0;
			image_speed = 1;
			
			vspd = -jspd;	// Jump
		},
		step: function() {
			// Play the animation once
			if (animation_end()) {
				image_speed = 0;
				image_index = image_number - 1;
			}
			
			recall_sword();
			apply_gravity();
			move_and_collide();
		}
	})
	.add("fall", {
		enter: function() {
			sprite_index = get_sprite();
			image_index = 0;
			image_speed = 1;
			
			// If I have not done air attack when falling now, activate air attack
			// Air attack can be done once when falling
			if (fsm.state_is("airAttack", fsm.get_previous_state())) canAirAttack = false;
				else canAirAttack = true;
			
		},
		step: function() {
			// Play the animation once
			if (animation_end()) {
				image_speed = 0;
				image_index = image_number - 1;
			}
			
			set_movement();
			recall_sword();
			apply_gravity();
			move_and_collide();
		}
	})
	.add("attack", {
		enter: function() {
			sprite_index = get_sprite();
			image_index = 0;
			image_speed = 1;
			
			nextAttack = false;
			
			// Create effect
			var _sprite = effectSprites[$ fsm.get_current_state()];
			var _face = face;
			var _x = x + _face * 8;
			with (instance_create_depth(_x, y, depth, oEffect)) {
				sprite_index = _sprite;
				image_xscale = _face;
			}
		},
		step: function() {
			// If attack key is pressed any time during the current state,
			// go to the next attack state after the animation ends
			if (input.attack) {
				nextAttack = true;	
			}
		}
	})
	.add_child("attack", "groundAttack", {
		/// @override
		enter: function() {
			fsm.inherit();
			
			// Stop
			hspd = 0;
			vspd = 0;
		},
	})
	.add_child("groundAttack", "groundAttack1")
	.add_child("groundAttack", "groundAttack2")
	.add_child("groundAttack", "groundAttack3")
	.add_child("attack", "airAttack", {
		/// @override
		enter: function() {
			fsm.inherit();
			
			// Lower the gravity
			grav = gravAttack;
			vspd = 0;
		},			
		/// @override
		step: function() {
			fsm.inherit();
			
			// Go down, slowly
			apply_gravity();
			move_and_collide();
		},
		leave: function() {
			grav = gravGround;	
		}
	})
	.add_child("airAttack", "airAttack1")
	.add_child("airAttack", "airAttack2", {
		/// @override
		step: function() {
			// Go down, slowly
			apply_gravity();
			move_and_collide();
		}
	})
	.add("throwSword", {
		enter: function() {
			sprite_index = get_sprite();
			image_index = 0;
			image_speed = 1;
			
			hspd = 0;
			vspd = 0;
			
			// Lower the gravity
			grav = gravAttack;
		},
		step: function() {
			// Movement
			apply_gravity();
			move_and_collide();
		},
		throwSword: function() {
			if (event_data[? "event_type"] == "sprite event") {
				spawn_sword();
				
				// Unequip the sword
				hasSword = false;
			}
		},
		leave: function() {
			grav = gravGround;	
		}
	})
	.add_transition("t_run", "idle", "run")
	.add_transition("t_jump", ["idle", "run"], "jump")
	.add_transition("t_attack", ["idle", "run"], "groundAttack1", function() { return hasSword; })
	.add_transition("t_attack", "fall", "airAttack1", function() { return (hasSword && canAirAttack); })
	.add_transition("t_throw", ["idle", "run", "jump", "fall"], "throwSword", function() { return hasSword; })
	.add_transition("t_coyote", "fall", "jump", function() {
		return (input.jump && (fsm.get_previous_state() == "run") && (fsm.get_time(false) <= coyoteDuration));
	})
	.add_transition("t_transition", ["idle", "run"], "fall", function() { return !on_ground(); })
	.add_transition("t_transition", "jump", "fall", function() { return (vspd >= 0); })
	.add_transition("t_transition", "run", "idle", function() { return (input.hdir == 0); })
	.add_transition("t_transition", ["fall", "airAttack"], "idle", function() { return on_ground(); })
	.add_transition("t_transition", "groundAttack1", "groundAttack2", function() { return (nextAttack && animation_end()); })
	.add_transition("t_transition", "groundAttack1", "idle", function() { return animation_end(); })
	.add_transition("t_transition", "groundAttack2", "groundAttack3", function() { return (nextAttack && animation_end()); })
	.add_transition("t_transition", ["groundAttack2", "groundAttack3"], "idle", function() { return animation_end(); })
	.add_transition("t_transition", "airAttack1", "airAttack2", function() { return (nextAttack && animation_end()); })
	.add_transition("t_transition", ["airAttack1", "airAttack2"], "fall", function() { return animation_end(); })
	.add_transition("t_transition", "throwSword", "fall", function() { return ((fsm.get_previous_state() == "jump") && animation_end()); })
	.add_transition("t_transition", "throwSword", "fall", function() { return ((fsm.get_previous_state() == "fall") && animation_end()); })
	.add_transition("t_transition", "throwSword", "idle", function() { return animation_end(); });
