import { createBrowserRouter, Navigate } from "react-router-dom";
import { RequireAuth, RedirectIfAuthed } from "@/app/guards";
import { ShellScaffold } from "@/shared/components/ShellScaffold";
import { LoginPage } from "@/features/auth/LoginPage";
import { OrgPickerPage } from "@/features/auth/OrgPickerPage";
import { FlowPage } from "@/features/flow/FlowPage";
import { ModulePage } from "@/features/module/ModulePage";
import { SquadPage } from "@/features/squad/SquadPage";
import { CopyPage } from "@/features/copy/CopyPage";
import { EditorialPage } from "@/features/editorial/EditorialPage";
import { InstagramPostPage } from "@/features/instagram-post/InstagramPostPage";
import { InstagramN3Page } from "@/features/instagram-n3/InstagramN3Page";
import { AudioVisualizerPage } from "@/features/audio-visualizer/AudioVisualizerPage";
import { VideoCaptionPage } from "@/features/video-caption/VideoCaptionPage";

export const router = createBrowserRouter([
  { path: "/", element: <Navigate to="/org-picker" replace /> },
  {
    element: <RedirectIfAuthed />,
    children: [{ path: "/login", element: <LoginPage /> }],
  },
  {
    element: <RequireAuth />,
    children: [
      { path: "/org-picker", element: <OrgPickerPage /> },
      {
        element: <ShellScaffold />,
        children: [
          { path: "/flows/:slug", element: <FlowPage /> },
          { path: "/modules/:slug", element: <ModulePage /> },
          { path: "/squads/:slug", element: <SquadPage /> },
          { path: "/copy", element: <CopyPage /> },
          { path: "/editorial", element: <EditorialPage /> },
          { path: "/instagram-post", element: <InstagramPostPage /> },
          { path: "/instagram-n3", element: <InstagramN3Page /> },
          { path: "/audio-visualizer", element: <AudioVisualizerPage /> },
          { path: "/video-caption", element: <VideoCaptionPage /> },
        ],
      },
    ],
  },
  { path: "*", element: <Navigate to="/" replace /> },
]);
