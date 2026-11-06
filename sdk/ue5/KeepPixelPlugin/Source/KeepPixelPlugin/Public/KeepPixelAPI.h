#pragma once
#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "KeepPixelAPI.generated.h"

USTRUCT(BlueprintType)
struct FKeepPixelProfile
{
    GENERATED_BODY()
    UPROPERTY(BlueprintReadOnly, Category="Keep Pixel") FString GlobalID;
    UPROPERTY(BlueprintReadOnly, Category="Keep Pixel") FString Username;
    UPROPERTY(BlueprintReadOnly, Category="Keep Pixel") FString Name;
    UPROPERTY(BlueprintReadOnly, Category="Keep Pixel") FString Avatar;
    UPROPERTY(BlueprintReadOnly, Category="Keep Pixel") FString Banner;
    UPROPERTY(BlueprintReadOnly, Category="Keep Pixel") FString Bio;
};
USTRUCT(BlueprintType)
struct FKeepPixelFriend
{
    GENERATED_BODY()
    UPROPERTY(BlueprintReadOnly, Category="Keep Pixel") FString GlobalID;
    UPROPERTY(BlueprintReadOnly, Category="Keep Pixel") FString Username;
    UPROPERTY(BlueprintReadOnly, Category="Keep Pixel") FString Name;
    UPROPERTY(BlueprintReadOnly, Category="Keep Pixel") FString Avatar;
    UPROPERTY(BlueprintReadOnly, Category="Keep Pixel") FString Presence;
    UPROPERTY(BlueprintReadOnly, Category="Keep Pixel") FString GameID;
    UPROPERTY(BlueprintReadOnly, Category="Keep Pixel") FString GameTitle;
};
UENUM(BlueprintType)
enum class EKeepPixelPresence : uint8 { InGame, Away };
DECLARE_DYNAMIC_DELEGATE_ThreeParams(FKeepPixelProfileResult, bool, Success, const FKeepPixelProfile&, Profile, const FString&, Error);
DECLARE_DYNAMIC_DELEGATE_ThreeParams(FKeepPixelFriendsResult, bool, Success, const TArray<FKeepPixelFriend>&, Friends, const FString&, Error);
DECLARE_DYNAMIC_DELEGATE_ThreeParams(FKeepPixelLicenseResult, bool, Success, bool, Owned, const FString&, Error);
DECLARE_DYNAMIC_DELEGATE_TwoParams(FKeepPixelResult, bool, Success, const FString&, Error);

UCLASS()
class KEEPPIXELPLUGIN_API UKeepPixelAPI : public UBlueprintFunctionLibrary
{
    GENERATED_BODY()
public:
    // Call at GameInstance Init. In the editor, use the SDK development host.
    UFUNCTION(BlueprintCallable, Category="Keep Pixel|SDK")
    static bool InitializeFromLauncher(FString& Error);
    UFUNCTION(BlueprintPure, Category="Keep Pixel|SDK")
    static int32 GetGameID();
    UFUNCTION(BlueprintCallable, Category="Keep Pixel|Profile")
    static void GetUserProfile(FKeepPixelProfileResult Completed);
    UFUNCTION(BlueprintCallable, Category="Keep Pixel|Friends")
    static void GetFriendsList(FKeepPixelFriendsResult Completed);
    UFUNCTION(BlueprintCallable, Category="Keep Pixel|License")
    static void CheckLicense(FKeepPixelLicenseResult Completed);
    UFUNCTION(BlueprintCallable, Category="Keep Pixel|Presence")
    static void SetPresence(EKeepPixelPresence Presence, FKeepPixelResult Completed);
    UFUNCTION(BlueprintCallable, Category="Keep Pixel|Overlay")
    static void SetOverlayVisible(bool Visible, FKeepPixelResult Completed);
};
