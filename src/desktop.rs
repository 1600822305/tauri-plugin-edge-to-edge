use serde::de::DeserializeOwned;
use tauri::{plugin::PluginApi, AppHandle, Runtime};

use crate::models::*;

pub fn init<R: Runtime, C: DeserializeOwned>(
  app: &AppHandle<R>,
  _api: PluginApi<R, C>,
) -> crate::Result<EdgeToEdge<R>> {
  Ok(EdgeToEdge(app.clone()))
}

/// Access to the edge-to-edge APIs.
pub struct EdgeToEdge<R: Runtime>(AppHandle<R>);

impl<R: Runtime> EdgeToEdge<R> {
  /// 桌面端返回零安全区域
  pub fn get_safe_area_insets(&self) -> crate::Result<SafeAreaInsets> {
    Ok(SafeAreaInsets::default())
  }
  
  /// 桌面端不需要 Edge-to-Edge
  pub fn enable(&self) -> crate::Result<()> {
    Ok(())
  }
  
  /// 桌面端不需要 Edge-to-Edge
  pub fn disable(&self) -> crate::Result<()> {
    Ok(())
  }
}
