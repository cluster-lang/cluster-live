// ==============================================================================
// Cluster-SSG: Standard Library Public Entry Point (std/ssg.cl)
// 100% Pure Cluster Language · Hugo Speed · Astro Islands · Jekyll Simplicity
// ==============================================================================

import "std/cld.cl"
import "std/ssg/document.cl"
import "std/ssg/template.cl"
import "std/ssg/islands.cl"
import "std/ssg/builder.cl"

// Convenience wrapper to run full static build
fn ssg_build_site(site_dir: string, dist_dir: string, is_binary: int) -> BuildReport:
    cfg := SsgConfig("Cluster SSG", "Next-Gen Blazing Fast Static Site Generator", "http://localhost:3000", site_dir, dist_dir, is_binary)
    return builder_run_all(cfg)

fn ssg_build_default() -> BuildReport:
    cfg := config_default()
    return builder_run_all(cfg)
