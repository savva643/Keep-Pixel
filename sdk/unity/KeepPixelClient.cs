// Unity 2021.3+ coroutine adapter; place under Assets/KeepPixel/.
using System;
using System.Collections;
using System.Text;
using System.Text.RegularExpressions;
using UnityEngine;
using UnityEngine.Networking;

namespace Necsoura.KeepPixel {
    [Serializable] public class SdkError { public string code; public string message; }
    [Serializable] public class Profile { public string global_id, username, name, avatar, banner, bio; }
    [Serializable] public class Friend { public string global_id, username, name, avatar, presence, game_title; public int game_id; }
    [Serializable] public class License { public int game_id; public bool owned; }
    [Serializable] public class Features { public bool profile, friends, license, presence, overlay, invites, achievements, cloud_saves; }
    [Serializable] public class Session { public int protocol, game_id; public string title; public Features features; }
    [Serializable] internal class Envelope<T> { public bool ok; public T data; public SdkError error; }
    [Serializable] internal class PresenceBody { public string status; }
    [Serializable] internal class OverlayBody { public bool visible; }
    [Serializable] public class Mutation { public int game_id; public string status; public bool visible; }

    public sealed class KeepPixelClient {
        private readonly string url, capability;
        public int GameId { get; }
        public KeepPixelClient() {
            url = Environment.GetEnvironmentVariable("KEEPPIXEL_SDK_URL") ?? "";
            capability = Environment.GetEnvironmentVariable("KEEPPIXEL_SDK_TOKEN") ?? "";
            Uri uri;
            int game;
            if (!Uri.TryCreate(url, UriKind.Absolute, out uri) || uri.Scheme != "http" ||
                uri.Host != "127.0.0.1" || uri.AbsolutePath != "/v1" || uri.UserInfo != "" ||
                uri.Query != "" || uri.Fragment != "" || uri.Port <= 0 ||
                !Regex.IsMatch(capability, @"^[A-Za-z0-9_-]{43}$") ||
                !int.TryParse(Environment.GetEnvironmentVariable("KEEPPIXEL_GAME_ID"), out game) || game <= 0)
                throw new InvalidOperationException("Start this game from Keep Pixel");
            GameId = game;
        }
        private IEnumerator Request<T>(string path, object body, Action<T> done, Action<SdkError> failed) {
            using (var request = new UnityWebRequest(url + path, body == null ? "GET" : "POST")) {
                request.downloadHandler = new DownloadHandlerBuffer();
                request.timeout = 8;
                request.redirectLimit = 0;
                request.SetRequestHeader("Authorization", "Bearer " + capability);
                request.SetRequestHeader("Accept", "application/json");
                if (body != null) {
                    request.uploadHandler = new UploadHandlerRaw(Encoding.UTF8.GetBytes(JsonUtility.ToJson(body)));
                    request.SetRequestHeader("Content-Type", "application/json");
                }
                yield return request.SendWebRequest();
                Envelope<T> envelope = null;
                try {
                    var bytes = request.downloadHandler.data;
                    if (bytes != null && bytes.Length <= 1024 * 1024)
                        envelope = JsonUtility.FromJson<Envelope<T>>(request.downloadHandler.text);
                } catch (ArgumentException) { }
                if (request.responseCode == 200 && envelope != null && envelope.ok) done?.Invoke(envelope.data);
                else failed?.Invoke(envelope?.error ?? new SdkError { code = "launcher_unavailable", message = "Keep Pixel request failed" });
            }
        }
        public IEnumerator GetSession(Action<Session> done, Action<SdkError> failed) => Request("/session", null, done, failed);
        public IEnumerator GetProfile(Action<Profile> done, Action<SdkError> failed) => Request("/profile", null, done, failed);
        public IEnumerator GetFriends(Action<Friend[]> done, Action<SdkError> failed) => Request("/friends", null, done, failed);
        public IEnumerator CheckLicense(Action<License> done, Action<SdkError> failed) => Request("/license", null, done, failed);
        public IEnumerator SetPresence(bool away, Action<Mutation> done, Action<SdkError> failed) =>
            Request("/presence", new PresenceBody { status = away ? "away" : "in_game" }, done, failed);
        public IEnumerator ShowOverlay(bool visible, Action<Mutation> done, Action<SdkError> failed) =>
            Request("/overlay", new OverlayBody { visible = visible }, done, failed);
    }
}
