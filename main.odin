package main
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:reflect"
import "core:slice"
import rl "vendor:raylib"
BULLETS :: 1000
ENEMIES :: 1000
BONUSES :: 1000
BACKGROUNDS :: 1000
FPS :: 60
BACKGROUND_SIZE :: 400
Player :: struct {
  pos:                rl.Vector2,
  speed:              f32,
  cannons:            int,
  bullet_damage:      int,
  bullet_penetration: int,
  lasers:             int,
}
Bullet :: struct {
  pos:         rl.Vector2,
  vel:         rl.Vector2,
  penetration: int,
  alive:       bool,
}
Enemy :: struct {
  pos:         rl.Vector2,
  vel:         rl.Vector2,
  hp:          i32,
  init_hp:     i32,
  is_boss:     bool,
  alive:       bool,
  is_wanderer: bool,
}
BonusType :: enum {
  NONE,
  SPEED,
  CANNON,
  DAMAGE,
  PENETRATION,
  LASER,
}
Bonus :: struct {
  pos:   rl.Vector2,
  speed: f32,
  typ:   BonusType,
  alive: bool,
}
Background :: struct {
  pos:   rl.Vector2,
  size:  f32,
  speed: f32,
  color: int,
  alive: bool,
}
Rocket :: struct {
  pos:   rl.Vector2,
  vel:   rl.Vector2,
  alive: bool,
}
DrawPlayer :: proc(p: Player, blink: bool = false) {
  rl.DrawPoly(p.pos, 3, 32, -90, blink ? rl.BLUE : rl.YELLOW)
}
MovePlayer :: proc(p: ^Player) {
  w := rl.GetScreenWidth()
  h := rl.GetScreenHeight()
  if rl.IsKeyDown(.LEFT) {
    p.pos.x = max(0, p.pos.x - p.speed)
  }
  if rl.IsKeyDown(.RIGHT) {
    p.pos.x = min(f32(w), p.pos.x + p.speed)
  }
  if rl.IsKeyDown(.DOWN) {
    p.pos.y = min(f32(h), p.pos.y + p.speed)
  }
  if rl.IsKeyDown(.UP) {
    p.pos.y = max(0, p.pos.y - p.speed)
  }
}
DrawBullet :: proc(b: Bullet) {
  rl.DrawCircleV(b.pos, max(1, math.sqrt(f32(b.penetration))), rl.WHITE)
}
MoveBullet :: proc(b: ^Bullet) {
  w := rl.GetScreenWidth()
  h := rl.GetScreenHeight()
  b.pos += b.vel
  if !rl.CheckCollisionPointRec(b.pos, {0, 0, f32(w), f32(h)}) {
    b.alive = false
  }
}
DrawEnemy :: proc(e: Enemy) {
  hp := min(300, max(16, e.hp))
  color := rl.ColorAlpha(rl.MAROON, 0.5)
  rl.DrawRectangle(i32(e.pos.x) - hp - i32(e.vel.x), i32(e.pos.y) - hp - i32(e.vel.y) * 2, hp * 2, hp * 2, color)
  rl.DrawRectangle(i32(e.pos.x) - hp, i32(e.pos.y) - hp, hp * 2, hp * 2, e.is_boss ? rl.MAROON : rl.RED)
  if e.is_boss {
    true_hp := i32(2 * f32(hp) * (f32(e.hp) / f32(e.init_hp)))
    rl.DrawRectangle(i32(e.pos.x) - hp, i32(e.pos.y) + hp - 5, true_hp, 5, rl.GREEN)
  }
}
MoveEnemy :: proc(e: ^Enemy, wave: f32) {
  w := rl.GetScreenWidth()
  h := rl.GetScreenHeight()
  e.pos += e.vel
  if e.pos.x < 0 || i32(e.pos.x) > w {
    e.vel.x *= -1
    e.pos.x += 2 * e.vel.x
    if e.is_boss {
      e.pos.y += 7 + wave
    }
  }
  if e.pos.x < 0 || i32(e.pos.x) > w || i32(e.pos.y) > h + e.hp {
    e.alive = false
  }
}
DrawBonus :: proc(b: Bonus) {
  color := rl.WHITE
  switch b.typ {
  case .SPEED:
    color = rl.GREEN
  case .CANNON:
    color = rl.GOLD
  case .DAMAGE:
    color = rl.MAGENTA
  case .PENETRATION:
    color = rl.PURPLE
  case .LASER:
    color = rl.BROWN
  case .NONE:
    break
  }
  rl.DrawPoly(b.pos, 6, 16, 0, color)
}
MoveBonus :: proc(b: ^Bonus) {
  w := rl.GetScreenWidth()
  h := rl.GetScreenHeight()
  b.pos.y += b.speed
  if !rl.CheckCollisionPointRec(b.pos, {0, 0, f32(w), f32(h)}) {
    b.alive = false
  }
}
DrawBackground :: proc(b: Background) {
  rl.DrawPoly(b.pos, 4, b.size, 45, {0, 0, u8(b.color), 255})
}
MoveBackground :: proc(b: ^Background) {
  w := rl.GetScreenWidth()
  h := rl.GetScreenHeight()
  b.pos.y += b.speed
  if b.pos.x < 0 || b.pos.y < -b.size || b.pos.x > f32(w) || b.pos.y > f32(h) + b.size {
    b.alive = false
  }
}
generate_background :: proc(backgrounds: []Background, dead_background: ^int, initial: bool = false) {
  small_back: i32 = BACKGROUND_SIZE / 10
  background := &backgrounds[dead_background^]
  background.alive = true
  background.size = f32(rl.GetRandomValue(small_back, BACKGROUND_SIZE))
  background.pos.x = f32(rl.GetRandomValue(0, rl.GetScreenWidth()))
  background.pos.y = initial ? f32(rl.GetRandomValue(0, rl.GetScreenHeight())) : -backgrounds[dead_background^].size
  background.color = int(64 + (background.size / BACKGROUND_SIZE * 128))
  background.speed = 0.1 * background.size / f32(small_back)
  for {
    dead_background^ = (dead_background^ + 1) % BACKGROUNDS
    if !backgrounds[dead_background^].alive {
      break
    }
  }
  slice.sort_by(backgrounds[:], proc(a, b: Background) -> bool {return a.size < b.size})
}
main :: proc() {
  rl.SetRandomSeed(rand.uint32())
  rl.SetTextLineSpacing(2)
  win_w: i32 = 1000
  win_h: i32 = 1000
  rl.InitWindow(win_w, win_h, "SLJ")
  rl.SetExitKey(.F10)
  rl.SetTargetFPS(FPS)
  p := Player{{f32(win_w) / 2, f32(win_h) - 40}, 5, 1, 10, 1, 0}
  bullets: [BULLETS]Bullet
  enemies: [ENEMIES]Enemy
  bonuses: [BONUSES]Bonus
  backgrounds: [BACKGROUNDS]Background
  rocket: Rocket
  dead_bullet := 0
  dead_enemy := 0
  dead_bonus := 0
  dead_background := 0
  frame_counter := 0
  frame_counter_backup := 0
  game_over := false
  pause := true
  boss_is_here := false
  mute := true
  blink_player := 0
  score := 0
  wave := 1
  rl.InitAudioDevice()
  psound := rl.LoadSound("p.ogg")
  last_rocket_alive := false
  for _ in 0 ..< 10 {
    generate_background(backgrounds[:], &dead_background, true)
  }
  for !rl.WindowShouldClose() {
    if !game_over && !pause {
      if frame_counter % 6 == 0 {
        for i in 0 ..< p.cannons {
          bullet := &bullets[dead_bullet]
          bullet.alive = true
          bullet.vel.y = -10
          n := p.cannons == 1 ? 0 : f32(i) - (f32(p.cannons - 1) / 2.0)
          bullet.pos = {p.pos.x + n * 5, p.pos.y}
          bullet.vel.x = n
          bullet.penetration = p.bullet_penetration
          for {
            dead_bullet = (dead_bullet + 1) % BULLETS
            if !bullets[dead_bullet].alive {
              break
            }
          }
        }
      }
      difficulty := frame_counter / 360
      frequency := 30 - difficulty - wave
      iterations := 1
      if frequency <= 0 {
        iterations = max(-frequency, 1)
        frequency = 1
      }
      if frame_counter % frequency == 0 {
        outer: for i in 0 ..< iterations {
          enemy := &enemies[dead_enemy]
          enemy.alive = true
          enemy.pos.x = f32(rl.GetRandomValue(0, rl.GetScreenWidth()))
          if !boss_is_here && wave % 3 == 0 {
            boss_is_here = true
            enemy.vel = {5, 0}
            enemy.hp = i32(wave - 3) * 100_000 + 100_000
            enemy.is_boss = true
            enemy.pos.y = 0
          } else {
            enemy.is_wanderer = rl.GetRandomValue(1, 100) == 1
            enemy.vel = {enemy.is_wanderer ? f32(rl.GetRandomValue(-i32(wave), i32(wave))) : 0, 3 + f32(wave) + (2 - math.log10(f32(rl.GetRandomValue(1, 1000))))}
            enemy.hp = rl.GetRandomValue(10, 70) + i32(difficulty * wave)
            enemy.is_boss = false
            enemy.pos.y = f32(-enemy.hp)
          }
          enemy.init_hp = enemy.hp
          old_dead_enemy := dead_enemy
          for {
            dead_enemy = (dead_enemy + 1) % ENEMIES
            if !enemies[dead_enemy].alive {
              break
            }
            if dead_enemy == old_dead_enemy {
              break outer
            }
          }
        }
      }
      if frame_counter % 900 == 0 {
        bonus := &bonuses[dead_bonus]
        bonus.alive = true
        bonus.speed = 4
        bonus.pos = {f32(rl.GetRandomValue(0, rl.GetScreenWidth())), 0}
        bonus.typ = BonusType(rl.GetRandomValue(1, i32(len(reflect.enum_field_names(BonusType))) - 1))
        for {
          dead_bonus = (dead_bonus + 1) % BONUSES
          if !bonuses[dead_bonus].alive {
            break
          }
        }
      }
      if frame_counter % 120 == 0 {
        generate_background(backgrounds[:], &dead_background)
      }
      if frame_counter % 1200 == 0 {
        if !rocket.alive {
          rocket.alive = true
          rocket.pos = p.pos
          rocket.vel = {0, -5}
        }
      }
      MovePlayer(&p)
      for &background in backgrounds {
        if background.alive {
          MoveBackground(&background)
        }
      }
      for &bullet in bullets {
        if bullet.alive {
          MoveBullet(&bullet)
        }
      }
      for &bonus in bonuses {
        if bonus.alive {
          MoveBonus(&bonus)
        }
      }
      for &enemy in enemies {
        if enemy.alive {
          MoveEnemy(&enemy, f32(wave))
        }
      }
      if !rocket.alive {
        rocket.pos += rocket.vel
      }
    }
    rl.BeginDrawing()
    rl.ClearBackground(rl.BLACK)
    for background in backgrounds {
      if background.alive {
        DrawBackground(background)
      }
    }
    for enemy in enemies {
      if enemy.alive {
        DrawEnemy(enemy)
      }
    }
    for bullet in bullets {
      if bullet.alive {
        DrawBullet(bullet)
      }
    }
    for bonus in bonuses {
      if bonus.alive {
        DrawBonus(bonus)
      }
    }
    if rocket.alive {
      rocket.pos += rocket.vel
    }
    if p.lasers > 0 {
      laser_freq := max(10, FPS / p.lasers)
      if !game_over && !pause && (frame_counter % laser_freq < 3 || frame_counter % laser_freq > (laser_freq - 3)) {
        rl.DrawRectangleV({p.pos.x - 1, 0}, {3, p.pos.y}, rl.LIME)
      }
    }
    DrawPlayer(p, bool(blink_player))
    blink_player = max(0, blink_player - 1)
    if rocket.alive {
      rl.DrawCircle(i32(rocket.pos.x - rocket.vel.x * (3 + 0.5 * f32(rl.GetRandomValue(1, 5)))), i32(rocket.pos.y - rocket.vel.y * (3 + 0.5 * f32(rl.GetRandomValue(1, 5)))), f32(rl.GetRandomValue(5, 15)), rl.ORANGE)
      rl.DrawPoly(rocket.pos, 3, 16, rl.RAD2DEG * math.atan2(rocket.vel.x, rocket.vel.y), rl.ORANGE)
    }
    if game_over {
      w := rl.MeasureText("GAME OVER", 72)
      rl.DrawText("GAME OVER", (rl.GetScreenWidth() - w) / 2, rl.GetScreenHeight() / 2 - 36, 72, rl.RAYWHITE)
    }
    if pause {
      w := rl.MeasureText("PAUSE", 72)
      rl.DrawText("PAUSE", (rl.GetScreenWidth() - w) / 2, rl.GetScreenHeight() / 2 - 36, 72, rl.RAYWHITE)
    }
    rl.DrawText(
      fmt.ctprintf(
        "Score: {:v}\nWave: {:v}\nStage: {:v}\nSpeed: {:v}\nBullet damage: {:v}\nBullet penetration: {:v}\nCannons: {:v}\nLasers: {:v}\nFirepower: {:v}/s\n",
        score,
        wave,
        frame_counter / 360 + 1,
        p.speed,
        p.bullet_damage,
        p.bullet_penetration,
        p.cannons,
        p.lasers,
        (p.bullet_damage * p.bullet_penetration - (p.bullet_penetration - 1) * p.bullet_penetration / 2) * p.cannons * 10 + (p.bullet_damage * p.bullet_penetration * p.lasers * 9),
      ),
      10,
      10,
      20,
      rl.RAYWHITE,
    )
    if last_rocket_alive && !rocket.alive {
      rl.DrawCircleV(rocket.pos, 100, rl.WHITE)
    }
    last_rocket_alive = rocket.alive
    rl.EndDrawing()
    if rl.IsKeyPressed(.M) {
      mute = !mute
    }
    if !game_over && rl.IsKeyPressed(.SPACE) {
      pause = !pause
      if pause {
        frame_counter_backup = frame_counter
      } else {
        frame_counter = frame_counter_backup
      }
    }
    if game_over && rl.IsKeyPressed(.SPACE) {
      score = 0
      wave = 1
      boss_is_here = false
      for &background in backgrounds {
        background.alive = false
      }
      for &bullet in bullets {
        bullet.alive = false
      }
      for &enemy in enemies {
        enemy.alive = false
      }
      for &bonus in bonuses {
        bonus.alive = false
      }
      p = Player{{f32(win_w / 2), f32(win_h - 40)}, 5, 1, 10, 1, 0}
      rocket.alive = false
      game_over = false
      pause = true
      frame_counter = 0
      for _ in 0 ..< 10 {
        generate_background(backgrounds[:], &dead_background, true)
      }
    }
    if !game_over && !pause {
      min_d := max(f32)
      min_idx := 0
      for &enemy, index in enemies {
        if enemy.alive {
          if rocket.alive && rl.CheckCollisionRecs({rocket.pos.x - 10, rocket.pos.y - 10, 20, 20}, {enemy.pos.x - 10, enemy.pos.y - 10, 20, 20}) {
            enemy.alive = false
            rocket.alive = false
            continue
          }
          if rocket.alive {
            d := rl.Vector2Distance(rocket.pos, enemy.pos)
            if d < min_d {
              min_d = d
              min_idx = index
            }
          }
          hp := f32(min(300, max(16, enemy.hp)))
          if rl.CheckCollisionCircleRec(p.pos, 12, {enemy.pos.x - hp, enemy.pos.y - hp, hp * 2, hp * 2}) {
            game_over = true
          }
        }
      }
      if rocket.alive {
        d := enemies[min_idx].pos - rocket.pos
        rocket.vel = 7 * d / min_d
      }
      for &bonus in bonuses {
        if bonus.alive {
          if rl.CheckCollisionRecs({p.pos.x - 15, p.pos.y - 15, 30, 30}, {bonus.pos.x - 10, bonus.pos.y - 10, 20, 20}) {
            switch bonus.typ {
            case .SPEED:
              p.speed += 1
            case .CANNON:
              p.cannons += 1
            case .DAMAGE:
              p.bullet_damage += 1
            case .PENETRATION:
              p.bullet_penetration += 1
            case .LASER:
              p.lasers += 1
            case .NONE:
              break
            }
            bonus.alive = false
            blink_player = 10
          }
        }
      }
      if p.lasers > 0 {
        laser_freq := max(10, FPS / p.lasers)
        if (frame_counter % laser_freq < 3 || frame_counter % laser_freq > (laser_freq - 3)) {
          for &enemy in enemies {
            if enemy.alive {
              hp := f32(min(300, max(16, enemy.hp)))
              if rl.CheckCollisionRecs({enemy.pos.x - hp, enemy.pos.y - hp, hp * 2, hp * 2}, {p.pos.x - 1, 0, 3, p.pos.y}) {
                enemy.hp -= i32((p.bullet_damage + max(0, p.lasers - 6)) * p.bullet_penetration)
                if enemy.hp <= 0 {
                  enemy.alive = false
                  score += int(enemy.init_hp) / 10
                }
              }
            }
          }
        }
      }
      for &bullet in bullets {
        if bullet.alive {
          for &enemy in enemies {
            if enemy.alive {
              hp := f32(min(300, max(16, enemy.hp)))
              rect := rl.Rectangle{enemy.pos.x - hp, enemy.pos.y - hp, hp * 2, hp * 2}
              if rl.CheckCollisionPointRec(bullet.pos, rect) {
                enemy.hp -= i32((p.bullet_damage - (p.bullet_penetration - bullet.penetration)))
                bullet.penetration -= 1
                if bullet.penetration == 0 {
                  bullet.alive = false
                }
                if enemy.hp <= 0 {
                  enemy.alive = false
                  if !mute && rl.IsSoundReady(psound) {
                    rl.PlaySound(psound)
                  }
                  if enemy.is_boss {
                    score += 1000 * (wave / 3)
                  } else {
                    score += int(enemy.init_hp) / 10
                  }
                }
              }
            }
          }
        }
      }
    }
    old_frame_counter := frame_counter
    frame_counter = (frame_counter + 1) % (FPS * 60)
    if !game_over && !pause && old_frame_counter > frame_counter {
      wave += 1
      boss_is_here = false
    }
  }
}
