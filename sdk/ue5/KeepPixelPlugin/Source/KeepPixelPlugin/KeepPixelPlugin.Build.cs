using UnrealBuildTool;
public class KeepPixelPlugin : ModuleRules
{
    public KeepPixelPlugin(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
        PublicDependencyModuleNames.AddRange(new[] { "Core", "CoreUObject", "Engine" });
        PrivateDependencyModuleNames.AddRange(new[] { "HTTP", "Json" });
    }
}
