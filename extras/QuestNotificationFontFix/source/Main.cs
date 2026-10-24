using System;
using System.Linq;
using System.Reflection;
using System.Collections.Generic;
using HarmonyLib;
using TMPro;
using UnityEngine;
using UnityModManagerNet;

namespace QuestNotificationFontFix
{
    public static class Main
    {
        private static UnityModManager.ModEntry entry;
        private static TMP_FontAsset japanese;
        private static Material originalMaterial;
        private static Material repairedMaterial;
        private static float retryTimer;
        private static int notificationCount;
        private static int diagnosticFailures;
        private static bool warned;
        private static readonly HashSet<TextMeshProUGUI> pendingLayout = new HashSet<TextMeshProUGUI>();
        private static readonly Dictionary<TextMeshProUGUI, float> objectiveSizes = new Dictionary<TextMeshProUGUI, float>();
        private static string status = "Waiting for a supported game SDF shader";

        public static bool Load(UnityModManager.ModEntry mod)
        {
            entry = mod;
            var harmony = new Harmony(mod.Info.Id);
            var names = new[] {
                "Kingmaker.UI.MVVM._PCView.QuestNotification.QuestNotificationAddendumPCView",
                "Kingmaker.UI.MVVM._PCView.QuestNotification.QuestNotificationObjectivesPCView",
                "Kingmaker.UI.MVVM._PCView.QuestNotification.QuestNotificationQuestPCView"
            };
            // Resolve every target before installing any hooks.
            var targets = names.Select(n => AccessTools.DeclaredMethod(AccessTools.TypeByName(n), "BindViewImplementation")).ToArray();
            if (targets.Any(m => m == null)) {
                mod.Logger.Error("Notification view methods differ from the inspected game version; no hooks installed.");
                return false;
            }
            foreach (var target in targets)
                harmony.Patch(target, postfix: new HarmonyMethod(typeof(Main), nameof(AfterBind)));
            var container = AccessTools.DeclaredMethod(AccessTools.TypeByName("Kingmaker.UI.MVVM._PCView.QuestNotification.QuestNotificatorView"), "TryShowPeek");
            if (container != null)
                harmony.Patch(container, postfix: new HarmonyMethod(typeof(Main), nameof(AfterBind)));
            mod.OnUpdate = Update;
            mod.OnLateUpdate = LateUpdate;
            mod.OnGUI = m => {
                GUILayout.Label(status);
                GUILayout.Label("Notification views repaired: " + notificationCount);
                GUILayout.Label("Diagnostic log failures ignored: " + diagnosticFailures);
                GUILayout.Label("Keep I18NFont4UnityGame ShouldOverrideAscii=false. Restart after disabling this mod.");
            };
            TryRepair();
            mod.Logger.Log("Installed 3 notification view hooks; runtime display still requires verification.");
            return true;
        }

        private static void LateUpdate(UnityModManager.ModEntry mod, float delta)
        {
            if (pendingLayout.Count == 0) return;
            var texts = pendingLayout.ToArray();
            pendingLayout.Clear();
            try {
                Canvas.ForceUpdateCanvases();
                foreach (var text in texts) {
                    if (text == null || !text.gameObject.activeInHierarchy) continue;
                    if (text.name == "ObjectiveNameText") FitObjective(text);
                    text.ForceMeshUpdate(false, true);
                    if (notificationCount <= 10) LogText(text, "after-layout");
                }
            } catch (Exception e) {
                if (!warned) { entry.Logger.Error("Delayed notification layout failed: " + e); warned = true; }
            }
        }

        private static void FitObjective(TextMeshProUGUI text)
        {
            float baseSize;
            if (!objectiveSizes.TryGetValue(text, out baseSize)) {
                baseSize = text.fontSize;
                objectiveSizes[text] = baseSize;
            }
            text.enableAutoSizing = false;
            text.enableWordWrapping = false;
            text.fontSize = baseSize;
            var rect = text.rectTransform.rect;
            var margin = text.margin;
            var width = Math.Max(1f, rect.width - margin.x - margin.z);
            var height = Math.Max(1f, rect.height - margin.y - margin.w);
            var preferred = text.GetPreferredValues(text.text, float.PositiveInfinity, float.PositiveInfinity);
            var scale = Math.Min(1f, Math.Min(width / Math.Max(1f, preferred.x), height / Math.Max(1f, preferred.y)) * 0.92f);
            text.fontSize = Math.Max(1f, baseSize * scale);
            text.overflowMode = TextOverflowModes.Truncate;
            text.SetAllDirty();
        }

        // Diagnostic reads can fail before TMP has built its textInfo. They must
        // never interrupt the actual repair or skip subsequent notification text.
        internal static void RunDiagnostic(Action action)
        {
            try { action(); }
            catch (Exception) { diagnosticFailures++; }
        }

        private static void LogText(TextMeshProUGUI text, string stage)
        {
            RunDiagnostic(() => {
                if (text == null || entry == null) return;
                var rect = text.rectTransform.rect;
                entry.Logger.Log(stage + " name=" + text.name + " length=" + (text.text?.Length ?? 0)
                    + " overflow=" + text.overflowMode + " rect=" + rect.width + "x" + rect.height
                    + " preferred=" + text.preferredWidth + "x" + text.preferredHeight
                    + " characters=" + (text.textInfo?.characterCount ?? 0) + " alpha=" + text.color.a
                    + " bounds=" + text.bounds.size);
            });
        }

        private static void Update(UnityModManager.ModEntry mod, float delta)
        {
            if (repairedMaterial != null) return;
            retryTimer += delta;
            if (retryTimer < 1f) return;
            retryTimer = 0f;
            TryRepair();
        }

        private static bool TryRepair()
        {
            try {
                if (japanese == null) {
                    var type = AppDomain.CurrentDomain.GetAssemblies()
                        .Select(a => a.GetType("I18NFont4UnityGame.I18NFont4UnityGame", false))
                        .FirstOrDefault(t => t != null);
                    japanese = type?.GetField("s_tmpTranslateFont", BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic)
                        ?.GetValue(null) as TMP_FontAsset;
                }
                if (japanese == null || japanese.material == null) return false;
                if (repairedMaterial != null) return true;
                originalMaterial = japanese.material;
                // Use an actual loaded game shader, rather than the incompatible shader
                // serialized inside the external Unity asset bundle.
                var native = Resources.FindObjectsOfTypeAll<TMP_FontAsset>()
                    .Where(f => f != null && f != japanese && IsUsable(f.material))
                    .Select(f => f.material.shader).FirstOrDefault();
                if (native == null) {
                    foreach (var name in new[] { "TextMeshPro/Distance Field", "TextMeshPro/Mobile/Distance Field" }) {
                        var candidate = Shader.Find(name);
                        if (candidate != null && candidate.isSupported) { native = candidate; break; }
                    }
                }
                if (native == null) return false;
                var copy = new Material(originalMaterial);
                copy.name = originalMaterial.name + " (local shader repair)";
                copy.shader = native;
                // Cloning preserves the Japanese atlas, gradient scale and font weights.
                if (!IsUsable(copy)) {
                    UnityEngine.Object.Destroy(copy);
                    return false;
                }
                japanese.material = copy;
                repairedMaterial = copy;
                status = "Japanese SDF material repaired: " + native.name;
                entry.Logger.Log(status + "; atlas preserved=" + (copy.mainTexture == originalMaterial.mainTexture));
                return true;
            } catch (Exception e) {
                if (!warned) { entry.Logger.Error("Font repair failed: " + e); warned = true; }
                return false;
            }
        }

        private static bool IsUsable(Material material)
        {
            return material != null && material.shader != null && material.shader.isSupported
                && material.shader.name.StartsWith("TextMeshPro/", StringComparison.Ordinal)
                && material.shader.name.IndexOf("Surface", StringComparison.OrdinalIgnoreCase) < 0
                && material.HasProperty("_GradientScale") && material.HasProperty("_MainTex");
        }

        public static void AfterBind(object __instance)
        {
            try {
                if (!TryRepair()) return;
                var view = __instance as Component;
                if (view == null) return;
                var texts = view.GetComponentsInChildren<TextMeshProUGUI>(true);
                var populated = 0;
                foreach (var text in texts) {
                    if (text == null || string.IsNullOrEmpty(text.text)) continue;
                    if (notificationCount < 10) LogText(text, "before-repair");
                    // Leave descriptions and headers on their native font/fallback.
                    // Direct replacement invokes the old MOD's overflow workaround,
                    // which makes long descriptions escape the notification panel.
                    if (text.name != "ObjectiveNameText") {
                        pendingLayout.Add(text);
                        continue;
                    }
                    text.font = japanese;
                    text.fontSharedMaterial = repairedMaterial;
                    FitObjective(text);
                    text.SetAllDirty();
                    text.ForceMeshUpdate(false, true);
                    pendingLayout.Add(text);
                    populated++;
                }
                notificationCount++;
                if (notificationCount <= 10)
                    entry.Logger.Log("Notification view " + notificationCount + ": nonempty text components=" + populated);
            } catch (Exception e) {
                if (!warned) { entry.Logger.Error("Notification repair failed: " + e); warned = true; }
            }
        }
    }
}
