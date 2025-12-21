using System;
using System.Runtime.InteropServices;
using UnityEngine;

/// <summary>
/// Bridge untuk komunikasi antara Unity dan Flutter
/// Script ini harus diletakkan di Unity project: Assets/Scripts/UnityBridge.cs
/// </summary>
public class UnityBridge : MonoBehaviour
{
    // Import fungsi dari Flutter plugin
    [DllImport("__Internal")]
    private static extern void sendToFlutter(string message);

    // Singleton instance
    private static UnityBridge instance;
    
    public static UnityBridge Instance
    {
        get
        {
            if (instance == null)
            {
                GameObject go = new GameObject("UnityBridge");
                instance = go.AddComponent<UnityBridge>();
                DontDestroyOnLoad(go);
            }
            return instance;
        }
    }

    void Awake()
    {
        if (instance == null)
        {
            instance = this;
            DontDestroyOnLoad(gameObject);
        }
        else if (instance != this)
        {
            Destroy(gameObject);
        }
    }

    void Start()
    {
        Debug.Log("UnityBridge initialized");
        SendMessageToFlutter("unity_loaded", "Unity AR scene loaded successfully");
    }

    /// <summary>
    /// Kirim message ke Flutter
    /// </summary>
    public void SendMessageToFlutter(string type, string data)
    {
        try
        {
            string json = $"{{\"type\":\"{type}\",\"data\":\"{data}\"}}";
            
#if UNITY_IOS && !UNITY_EDITOR
            sendToFlutter(json);
#else
            Debug.Log($"[UnityBridge] Would send to Flutter: {json}");
#endif
        }
        catch (Exception e)
        {
            Debug.LogError($"[UnityBridge] Error sending message: {e.Message}");
        }
    }

    /// <summary>
    /// Receive message dari Flutter
    /// Method ini akan dipanggil oleh Flutter via UnityWidget.sendToUnity()
    /// </summary>
    public void ReceiveMessageFromFlutter(string message)
    {
        Debug.Log($"[UnityBridge] Received from Flutter: {message}");
        
        try
        {
            // Parse JSON message
            MessageData data = JsonUtility.FromJson<MessageData>(message);
            
            switch (data.method)
            {
                case "start_measurement":
                    StartMeasurement();
                    break;
                    
                case "add_point":
                    AddMeasurementPoint();
                    break;
                    
                case "complete_measurement":
                    CompleteMeasurement();
                    break;
                    
                case "clear_measurements":
                    ClearMeasurements();
                    break;
                    
                default:
                    Debug.LogWarning($"[UnityBridge] Unknown method: {data.method}");
                    break;
            }
        }
        catch (Exception e)
        {
            Debug.LogError($"[UnityBridge] Error processing message: {e.Message}");
        }
    }

    private void StartMeasurement()
    {
        Debug.Log("[UnityBridge] Starting measurement...");
        SendMessageToFlutter("measurement_started", "Measurement session started");
        
        // TODO: Initialize AR plane detection
        // TODO: Enable placement mode
    }

    private void AddMeasurementPoint()
    {
        Debug.Log("[UnityBridge] Adding measurement point...");
        
        // TODO: Add point at current AR hit position
        // TODO: Calculate distance if multiple points exist
        
        // Example: Send back point data
        string pointData = $"{{\"x\":0.0,\"y\":0.0,\"z\":0.0,\"index\":1}}";
        SendMessageToFlutter("point_added", pointData);
    }

    private void CompleteMeasurement()
    {
        Debug.Log("[UnityBridge] Completing measurement...");
        
        // TODO: Calculate final measurements
        // TODO: Generate measurement result
        
        // Example: Send back measurement result
        string result = $"{{\"distance\":10.5,\"area\":25.3,\"points\":4}}";
        SendMessageToFlutter("measurement_complete", result);
    }

    private void ClearMeasurements()
    {
        Debug.Log("[UnityBridge] Clearing measurements...");
        
        // TODO: Remove all placed points
        // TODO: Reset measurement state
        
        SendMessageToFlutter("measurements_cleared", "All measurements cleared");
    }

    [Serializable]
    private class MessageData
    {
        public string method;
        public string data;
    }
}
