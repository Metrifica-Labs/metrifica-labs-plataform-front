import { z } from "zod";
import { loadFont as loadInter } from "@remotion/google-fonts/Inter";
import { loadFont as loadMontserrat } from "@remotion/google-fonts/Montserrat";
import { loadFont as loadPoppins } from "@remotion/google-fonts/Poppins";
import { loadFont as loadRoboto } from "@remotion/google-fonts/Roboto";
import { loadFont as loadRobotoMono } from "@remotion/google-fonts/RobotoMono";
import { AllowedFont } from "./motion-spec";

type AllowedFontName = z.infer<typeof AllowedFont>;

/**
 * Carrega as fontes permitidas e mapeia o nome (vocabulário do MotionSpec) para
 * a `fontFamily` real injetada pelo Remotion. Sem isto, o texto cai na fonte
 * serifada padrão do navegador — a principal causa do visual "amador".
 */
export const FONT_FAMILY: Record<AllowedFontName, string> = {
  Inter: loadInter().fontFamily,
  Roboto: loadRoboto().fontFamily,
  Montserrat: loadMontserrat().fontFamily,
  Poppins: loadPoppins().fontFamily,
  "Roboto Mono": loadRobotoMono().fontFamily,
};
