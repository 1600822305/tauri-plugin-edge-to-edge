const COMMANDS: &[&str] = &["get_safe_area_insets", "enable", "disable"];

fn main() {
  tauri_plugin::Builder::new(COMMANDS)
    .android_path("android")
    .ios_path("ios")
    .build();
}
