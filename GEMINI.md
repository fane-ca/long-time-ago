# Project Context: Long Time Ago (2D Deep-Sea Relic & Museum Sim)

## 1. Game Overview
- **Genre:** 2D Underwater Exploration / Relic Salvage + Museum Management Sim (inspired by *Dave the Diver* and *Stardew Valley*).
- **Setting:** Post-apocalyptic future after climate-induced ocean expansion and nuclear war wiped out most of humanity. The planet is now inhabited by other species. The player is a lone human survivor salvaging human relics from the sunken ruins to display in a museum commemorating humanity.

## 2. Engine & Technical Stack
- **Engine:** Godot Engine 4.x (strictly Godot 4 syntax, currently running 4.x stable).
- **Language:** GDScript 2.0 (strictly typed GDScript preferred).
- **Perspective:** 2D Side-scrolling (Underwater Diving Scene) & 2D Top-down/Side-view (Museum Scene).

## 3. Strict Coding Guidelines for AI Agent
- **NEVER use Godot 3 deprecated APIs:**
  - Use `@export` and `@onready` annotations instead of `export` / `onready`.
  - Use `CharacterBody2D` instead of `KinematicBody2D`.
  - Use `move_and_slide()` with zero arguments (set `velocity` property directly on the node).
  - Use `Sprite2D` instead of `Sprite`.
  - Use Godot 4 `Callable` syntax for signals (e.g., `signal_name.connect(_on_function)`).
- **Type Safety:** Always use static typing in GDScript where possible (e.g., `var speed: float = 200.0`, `func take_damage(amount: int) -> void:`).
- **Architecture:** Keep data-driven items (relics, prices, descriptions) decoupled from logic so new items and DLCs can be added easily via JSON or Custom `Resource` files.
- **Language:** Write all code, variable names, node names, and code comments in clear **English**.