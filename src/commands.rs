use tauri::{AppHandle, command, Runtime};

use crate::models::*;
use crate::Result;
use crate::EdgeToEdgeExt;

/// 获取安全区域
#[command]
pub(crate) async fn get_safe_area_insets<R: Runtime>(
    app: AppHandle<R>,
) -> Result<SafeAreaInsets> {
    app.edge_to_edge().get_safe_area_insets()
}

/// 启用 Edge-to-Edge
#[command]
pub(crate) async fn enable<R: Runtime>(
    app: AppHandle<R>,
) -> Result<()> {
    app.edge_to_edge().enable()
}

/// 禁用 Edge-to-Edge
#[command]
pub(crate) async fn disable<R: Runtime>(
    app: AppHandle<R>,
) -> Result<()> {
    app.edge_to_edge().disable()
}
