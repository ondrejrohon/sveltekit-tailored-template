import { layoutLoadHandler } from 'sveltekit-drizzle-lucia-template';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = layoutLoadHandler;
