import { layoutLoadHandler } from 'sveltekit-tailored';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = layoutLoadHandler;
