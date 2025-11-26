use serde::{Deserialize, Serialize};

/// 安全区域信息
#[derive(Debug, Clone, Default, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SafeAreaInsets {
  pub top: f64,
  pub right: f64,
  pub bottom: f64,
  pub left: f64,
}
