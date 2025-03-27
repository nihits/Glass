using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using TMPro;

public class TestGlass : MonoBehaviour
{
    public static TestGlass Instance;

    [SerializeField] private TMP_Text _frameRateText;
    [SerializeField] private TMP_Text _frameTimeText;
    [SerializeField] private TMP_InputField _vSyncInputField;
    [SerializeField] private TMP_InputField _targetFrameRateInputField;
    [SerializeField] private TMP_InputField _supportsCameraOpaqueTextureInputField;

    [SerializeField] private GameObject _glassGameObject;

    void Start()
    {
        Instance = this;
        DontDestroyOnLoad(gameObject);

        _vSyncInputField.text = QualitySettings.vSyncCount.ToString();
        _targetFrameRateInputField.text = Application.targetFrameRate.ToString();

        UniversalRenderPipelineAsset urpAsset = GraphicsSettings.currentRenderPipeline as UniversalRenderPipelineAsset;
        if (urpAsset != null)
        {
            _supportsCameraOpaqueTextureInputField.text = (urpAsset.supportsCameraOpaqueTexture ? 1 : 0).ToString();
        }
    }

    void Update()
    {
        if (_frameRateText != null)
        {
            _frameRateText.text = ((int)(1f / Time.deltaTime)).ToString();
        }

        if (_frameTimeText != null)
        {
            _frameTimeText.text = ((int)(1000f * Time.deltaTime)).ToString();
        }
    }

    public void ChangeVSync(string vSyncString)
    {
        int vSync = 1;
        bool parsed = int.TryParse(vSyncString, out vSync);
        if (parsed)
        {
            if (vSync < 0)
                vSync = 0;
            if (vSync > 2)
                vSync = 2;

            QualitySettings.vSyncCount = vSync;
            _vSyncInputField.text = vSync.ToString();
        }
        else
        {
            Debug.LogError($"TestGlass.ChangeVSync - VSync is invalid");
            _vSyncInputField.text = QualitySettings.vSyncCount.ToString();
        }
    }

    public void ChangeTargetFrameRate(string targetFrameRateString)
    {
        int targetFrameRate = 60;
        bool parsed = int.TryParse(targetFrameRateString, out targetFrameRate);
        if (parsed)
        {
            if (targetFrameRate < 0)
                targetFrameRate = 0;

            Application.targetFrameRate = targetFrameRate;
            _targetFrameRateInputField.text = targetFrameRate.ToString();
        }
        else
        {
            Debug.LogError($"TestGlass.ChangeTargetFrameRate - Target Frame Rate is invalid");
            _targetFrameRateInputField.text = Application.targetFrameRate.ToString();
        }
    }

    public void SetSupportsCameraOpaqueTexture(string supportsCameraOpaqueTextureString)
    {
        UniversalRenderPipelineAsset urpAsset = GraphicsSettings.currentRenderPipeline as UniversalRenderPipelineAsset;
        int suppportsCameraOpaqueTexture;
        bool parsed = int.TryParse(supportsCameraOpaqueTextureString, out suppportsCameraOpaqueTexture);
        if (parsed)
        {
            if (suppportsCameraOpaqueTexture < 0)
                suppportsCameraOpaqueTexture = 0;
            if (suppportsCameraOpaqueTexture > 1)
                suppportsCameraOpaqueTexture = 1;

            if (urpAsset != null)
            {
                urpAsset.supportsCameraOpaqueTexture = (suppportsCameraOpaqueTexture == 1) ? true : false;
            }

            _supportsCameraOpaqueTextureInputField.text = suppportsCameraOpaqueTexture.ToString();
        }
        else
        {
            Debug.LogError($"TestGlass.SetSupportsCameraOpaqueTexture - suppportsCameraOpaqueTexture is invalid");
            if (urpAsset != null)
            {
                _supportsCameraOpaqueTextureInputField.text = (urpAsset.supportsCameraOpaqueTexture ? 1 : 0).ToString();
            }
        }
    }

    public void ToggleGlass()
    {
        if (_glassGameObject != null)
        {
            _glassGameObject.SetActive(!_glassGameObject.activeSelf);
        }
    }
}
