#include "KeepPixelAPI.h"
#include "HAL/PlatformMisc.h"
#include "HttpModule.h"
#include "Interfaces/IHttpRequest.h"
#include "Interfaces/IHttpResponse.h"
#include "Dom/JsonObject.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Internationalization/Regex.h"

namespace {
struct FContext { FString URL; FString Capability; int32 GameID = 0; };
bool Context(FContext& Out, FString& Error)
{
    Out.URL = FPlatformMisc::GetEnvironmentVariable(TEXT("KEEPPIXEL_SDK_URL"));
    Out.Capability = FPlatformMisc::GetEnvironmentVariable(TEXT("KEEPPIXEL_SDK_TOKEN"));
    const FString ID = FPlatformMisc::GetEnvironmentVariable(TEXT("KEEPPIXEL_GAME_ID"));
    FRegexMatcher Match(FRegexPattern(TEXT("^http://127\\.0\\.0\\.1:([0-9]{1,5})/v1$")), Out.URL);
    if (!Match.FindNext() || Out.Capability.Len() != 43 || !ID.IsNumeric() ||
        !LexTryParseString(Out.GameID, *ID) || Out.GameID <= 0)
    { Error = TEXT("Launch this game from Keep Pixel; SDK environment is missing or invalid."); return false; }
    const int32 Port = FCString::Atoi(*Match.GetCaptureGroup(1));
    if (Port < 1 || Port > 65535) { Error = TEXT("Invalid local SDK port."); return false; }
    for (const TCHAR C : Out.Capability)
        if (!FChar::IsAlnum(C) && C != TEXT('_') && C != TEXT('-'))
        { Error = TEXT("Invalid local SDK capability."); return false; }
    Error.Reset(); return true;
}
using FResult = TFunction<void(bool, const TSharedPtr<FJsonValue>&, const FString&)>;
void Send(const FString& Verb, const FString& Path, const TSharedPtr<FJsonObject>& Body, FResult Done)
{
    FContext C; FString Error;
    if (!Context(C, Error)) { Done(false, nullptr, Error); return; }
    auto Request = FHttpModule::Get().CreateRequest();
    Request->SetURL(C.URL + Path);
    Request->SetVerb(Verb);
    Request->SetTimeout(8.0f);
    Request->SetHeader(TEXT("Authorization"), TEXT("Bearer ") + C.Capability);
    Request->SetHeader(TEXT("Accept"), TEXT("application/json"));
    if (Body.IsValid()) {
        FString Content;
        FJsonSerializer::Serialize(Body.ToSharedRef(), TJsonWriterFactory<>::Create(&Content));
        Request->SetHeader(TEXT("Content-Type"), TEXT("application/json"));
        Request->SetContentAsString(Content);
    }
    Request->OnProcessRequestComplete().BindLambda([Done](FHttpRequestPtr, FHttpResponsePtr Response, bool Connected) {
        if (!Connected || !Response.IsValid()) { Done(false, nullptr, TEXT("Keep Pixel launcher is unavailable.")); return; }
        if (Response->GetContentLength() > 1024 * 1024) { Done(false, nullptr, TEXT("SDK response exceeds limit.")); return; }
        TSharedPtr<FJsonObject> Envelope;
        if (!FJsonSerializer::Deserialize(TJsonReaderFactory<>::Create(Response->GetContentAsString()), Envelope) || !Envelope.IsValid())
        { Done(false, nullptr, TEXT("Invalid SDK response.")); return; }
        bool OK = false;
        Envelope->TryGetBoolField(TEXT("ok"), OK);
        if (!OK || Response->GetResponseCode() != 200) {
            FString Message = FString::Printf(TEXT("SDK request failed (HTTP %d)."), Response->GetResponseCode());
            const TSharedPtr<FJsonObject>* Failure = nullptr;
            if (Envelope->TryGetObjectField(TEXT("error"), Failure) && Failure && Failure->IsValid())
                (*Failure)->TryGetStringField(TEXT("message"), Message);
            Done(false, nullptr, Message); return;
        }
        const TSharedPtr<FJsonValue> Data = Envelope->TryGetField(TEXT("data"));
        if (!Data.IsValid()) { Done(false, nullptr, TEXT("SDK response has no data.")); return; }
        Done(true, Data, TEXT(""));
    });
    if (!Request->ProcessRequest()) Done(false, nullptr, TEXT("Cannot start SDK request."));
}
FString String(const TSharedPtr<FJsonObject>& Object, const TCHAR* Key) {
    FString Value; Object->TryGetStringField(Key, Value); return Value;
}
FString GameID(const TSharedPtr<FJsonObject>& Object) {
    double Value = 0;
    if (Object->TryGetNumberField(TEXT("game_id"), Value)) return FString::Printf(TEXT("%.0f"), Value);
    return String(Object, TEXT("game_id"));
}
}

bool UKeepPixelAPI::InitializeFromLauncher(FString& Error) { FContext C; return Context(C, Error); }
int32 UKeepPixelAPI::GetGameID() { FContext C; FString Error; return Context(C, Error) ? C.GameID : 0; }
void UKeepPixelAPI::GetUserProfile(FKeepPixelProfileResult Completed)
{
    Send(TEXT("GET"), TEXT("/profile"), nullptr, [Completed](bool OK, const TSharedPtr<FJsonValue>& Data, const FString& Error) {
        FKeepPixelProfile P;
        const bool Valid = OK && Data.IsValid() && Data->Type == EJson::Object;
        if (Valid) {
            const auto O = Data->AsObject();
            P.GlobalID = String(O, TEXT("global_id")); P.Username = String(O, TEXT("username"));
            P.Name = String(O, TEXT("name")); P.Avatar = String(O, TEXT("avatar"));
            P.Banner = String(O, TEXT("banner")); P.Bio = String(O, TEXT("bio"));
        }
        Completed.ExecuteIfBound(Valid, P, Valid ? FString() : (Error.IsEmpty() ? FString(TEXT("Invalid profile response.")) : Error));
    });
}
void UKeepPixelAPI::GetFriendsList(FKeepPixelFriendsResult Completed)
{
    Send(TEXT("GET"), TEXT("/friends"), nullptr, [Completed](bool OK, const TSharedPtr<FJsonValue>& Data, const FString& Error) {
        TArray<FKeepPixelFriend> Friends;
        bool Valid = OK && Data.IsValid() && Data->Type == EJson::Array;
        if (Valid) for (const auto& V : Data->AsArray()) {
            if (!V.IsValid() || V->Type != EJson::Object) { Valid = false; break; }
            const auto O = V->AsObject(); FKeepPixelFriend F;
            F.GlobalID = String(O, TEXT("global_id")); F.Username = String(O, TEXT("username"));
            F.Name = String(O, TEXT("name")); F.Avatar = String(O, TEXT("avatar"));
            F.Presence = String(O, TEXT("presence")); F.GameID = GameID(O); F.GameTitle = String(O, TEXT("game_title")); Friends.Add(F);
        }
        if (!Valid) Friends.Reset();
        Completed.ExecuteIfBound(Valid, Friends, Valid ? FString() : (Error.IsEmpty() ? FString(TEXT("Invalid friends response.")) : Error));
    });
}
void UKeepPixelAPI::CheckLicense(FKeepPixelLicenseResult Completed)
{
    Send(TEXT("GET"), TEXT("/license"), nullptr, [Completed](bool OK, const TSharedPtr<FJsonValue>& Data, const FString& Error) {
        bool Owned = false;
        const bool Valid = OK && Data.IsValid() && Data->Type == EJson::Object && Data->AsObject()->TryGetBoolField(TEXT("owned"), Owned);
        Completed.ExecuteIfBound(Valid, Owned, Valid ? FString() : (Error.IsEmpty() ? FString(TEXT("Invalid license response.")) : Error));
    });
}
void UKeepPixelAPI::SetPresence(EKeepPixelPresence Presence, FKeepPixelResult Completed)
{
    auto Body = MakeShared<FJsonObject>();
    Body->SetStringField(TEXT("status"), Presence == EKeepPixelPresence::Away ? TEXT("away") : TEXT("in_game"));
    Send(TEXT("POST"), TEXT("/presence"), Body, [Completed](bool OK, const TSharedPtr<FJsonValue>&, const FString& Error) { Completed.ExecuteIfBound(OK, Error); });
}
void UKeepPixelAPI::SetOverlayVisible(bool Visible, FKeepPixelResult Completed)
{
    auto Body = MakeShared<FJsonObject>(); Body->SetBoolField(TEXT("visible"), Visible);
    Send(TEXT("POST"), TEXT("/overlay"), Body, [Completed](bool OK, const TSharedPtr<FJsonValue>&, const FString& Error) { Completed.ExecuteIfBound(OK, Error); });
}
