import { useColorScheme } from 'react-native';

/** "Linen & Forest" — warm paper neutrals, deep forest ink and a terracotta accent. */
const light = {
  canvas: '#F4EFE7',
  surface: '#FFFDF9',
  surfaceMuted: '#EBE4D8',
  ink: '#17201C',
  ink2: '#5D6962',
  ink3: '#8C958F',
  hairline: '#E3DBCE',
  accent: '#CF5F3B',
  sage: '#4F7F63',
  butter: '#B9861E',
  sky: '#3F73A0',
  plum: '#7A5797',
  danger: '#B5382E',
};

const dark: typeof light = {
  canvas: '#0E1311',
  surface: '#171E1B',
  surfaceMuted: '#232C28',
  ink: '#F1ECE3',
  ink2: '#A8B2AC',
  ink3: '#7B8680',
  hairline: '#2C3632',
  accent: '#EE875F',
  sage: '#86B596',
  butter: '#F0C463',
  sky: '#7FAAD3',
  plum: '#B096CF',
  danger: '#EC6A5D',
};

export const fixed = {
  forest: '#1D3529',
  forestDeep: '#12231B',
  cream: '#F6F0E4',
  gold: '#F3D38A',
};

export type Palette = typeof light & typeof fixed & { scheme: 'light' | 'dark' };

export function useTheme(): Palette {
  const scheme = useColorScheme() === 'dark' ? 'dark' : 'light';
  return { ...(scheme === 'dark' ? dark : light), ...fixed, scheme };
}

export const petColors = (c: Palette) => [c.accent, c.sage, c.sky, c.plum, c.butter];

export const fonts = {
  display: 'Newsreader_600SemiBold',
  displayItalic: 'Newsreader_500Medium_Italic',
  body: 'Inter_400Regular',
  medium: 'Inter_500Medium',
  semibold: 'Inter_600SemiBold',
  bold: 'Inter_700Bold',
};

export const radius = { card: 24, medium: 16, small: 12 };
