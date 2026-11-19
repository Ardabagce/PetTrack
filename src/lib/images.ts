import { Platform } from 'react-native';
import * as ImageManipulator from 'expo-image-manipulator';
import * as ImagePicker from 'expo-image-picker';

/**
 * Picks or takes a photo and returns a resized JPEG data URI.
 * Photos are stored inline so the data stays portable (export, backup, web preview).
 */
export async function pickPhoto(source: 'camera' | 'library', maxWidth = 1200): Promise<string | undefined> {
  if (source === 'camera') {
    const permission = await ImagePicker.requestCameraPermissionsAsync();
    if (!permission.granted) return undefined;
  }
  const options: ImagePicker.ImagePickerOptions = { mediaTypes: ['images'], quality: 0.8, allowsEditing: false };
  const result = source === 'camera' && Platform.OS !== 'web'
    ? await ImagePicker.launchCameraAsync(options)
    : await ImagePicker.launchImageLibraryAsync(options);
  if (result.canceled || !result.assets[0]) return undefined;
  const asset = result.assets[0];
  try {
    const resized = await ImageManipulator.manipulateAsync(
      asset.uri,
      asset.width > maxWidth ? [{ resize: { width: maxWidth } }] : [],
      { compress: 0.72, format: ImageManipulator.SaveFormat.JPEG, base64: true },
    );
    return resized.base64 ? `data:image/jpeg;base64,${resized.base64}` : resized.uri;
  } catch {
    return asset.uri;
  }
}
