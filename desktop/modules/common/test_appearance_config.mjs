import assert from "node:assert/strict";

// Test schema migration and inheritance logic
function normalize(value) {
    const number = Number(value);
    return Number.isFinite(number) ? Math.max(0.0, Math.min(1.0, number)) : NaN;
}

function computeEffective(state) {
    const dockBlur = Number.isFinite(normalize(state.dockBlurStrength)) ? normalize(state.dockBlurStrength) : 0.42;
    const dockLiquid = Number.isFinite(normalize(state.dockLiquidStrength)) ? normalize(state.dockLiquidStrength) : 1.0;
    
    const barInherit = state.barBlurInheritDock !== false;
    const barBlur = barInherit ? dockBlur : (Number.isFinite(normalize(state.barBlurStrength)) ? normalize(state.barBlurStrength) : 0.42);
    const barLiquid = barInherit ? dockLiquid : (Number.isFinite(normalize(state.barLiquidStrength)) ? normalize(state.barLiquidStrength) : 1.0);

    const launcherInherit = state.launcherBlurInheritDock !== false;
    const launcherBlur = launcherInherit ? dockBlur : (Number.isFinite(normalize(state.launcherBlurStrength)) ? normalize(state.launcherBlurStrength) : 0.42);
    const launcherLiquid = launcherInherit ? dockLiquid : (Number.isFinite(normalize(state.launcherLiquidStrength)) ? normalize(state.launcherLiquidStrength) : 1.0);

    return {
        dockBlur, dockLiquid,
        barInherit, barBlur, barLiquid,
        launcherInherit, launcherBlur, launcherLiquid
    };
}

function migrateFromV4(v4) {
    return {
        version: 5,
        dockBlurStrength: v4.dockBlurStrength ?? v4.blurStrength ?? 0.42,
        dockLiquidStrength: v4.dockLiquidStrength ?? v4.liquidStrength ?? 1.0,
        barBlurInheritDock: v4.barBlurInheritDock ?? true,
        barBlurStrength: v4.barBlurStrength ?? 0.42,
        barLiquidStrength: v4.barLiquidStrength ?? 1.0,
        launcherBlurInheritDock: v4.launcherBlurInheritDock ?? true,
        launcherBlurStrength: v4.launcherBlurStrength ?? 0.42,
        launcherLiquidStrength: v4.launcherLiquidStrength ?? 1.0,
        shellStyle: v4.shellStyle ?? "macos",
        barIntegratedWithDock: v4.barIntegratedWithDock ?? false,
        barVisibilityMode: v4.barVisibilityMode ?? "always",
        barLayoutMode: v4.barLayoutMode ?? "full"
    };
}

// 1. Default inheritance
{
    const state = computeEffective({});
    assert.equal(state.dockBlur, 0.42);
    assert.equal(state.dockLiquid, 1.0);
    assert.equal(state.barInherit, true);
    assert.equal(state.barBlur, 0.42);
    assert.equal(state.barLiquid, 1.0);
    assert.equal(state.launcherInherit, true);
    assert.equal(state.launcherBlur, 0.42);
    assert.equal(state.launcherLiquid, 1.0);
    console.log("ok: default inheritance test passed");
}

// 2. Modifying Dock when inherited updates Bar and Launcher
{
    const state = computeEffective({ dockBlurStrength: 0.8, dockLiquidStrength: 0.5 });
    assert.equal(state.dockBlur, 0.8);
    assert.equal(state.barBlur, 0.8);
    assert.equal(state.launcherBlur, 0.8);
    assert.equal(state.barLiquid, 0.5);
    assert.equal(state.launcherLiquid, 0.5);
    console.log("ok: dock propagation test passed");
}

// 3. Custom Bar & Launcher when inheritance is false
{
    const state = computeEffective({
        dockBlurStrength: 0.8,
        dockLiquidStrength: 0.5,
        barBlurInheritDock: false,
        barBlurStrength: 0.2,
        barLiquidStrength: 0.3,
        launcherBlurInheritDock: false,
        launcherBlurStrength: 0.95,
        launcherLiquidStrength: 0.1
    });
    assert.equal(state.dockBlur, 0.8);
    assert.equal(state.barBlur, 0.2);
    assert.equal(state.barLiquid, 0.3);
    assert.equal(state.launcherBlur, 0.95);
    assert.equal(state.launcherLiquid, 0.1);
    console.log("ok: independent values test passed");
}

// 4. Migration from v4
{
    const v4 = {
        version: 4,
        blurStrength: 0.6,
        liquidStrength: 0.7,
        shellStyle: "material",
        barIntegratedWithDock: true,
        barVisibilityMode: "smart"
    };
    const v5 = migrateFromV4(v4);
    assert.equal(v5.version, 5);
    assert.equal(v5.dockBlurStrength, 0.6);
    assert.equal(v5.dockLiquidStrength, 0.7);
    assert.equal(v5.barBlurInheritDock, true);
    assert.equal(v5.launcherBlurInheritDock, true);
    assert.equal(v5.shellStyle, "material");
    assert.equal(v5.barIntegratedWithDock, true);
    assert.equal(v5.barVisibilityMode, "smart");
    assert.equal(v5.barLayoutMode, "full");
    console.log("ok: v4 to v5 migration test passed");
}

console.log("ALL TESTS PASS");
