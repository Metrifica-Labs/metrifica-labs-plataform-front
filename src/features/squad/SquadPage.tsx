import { useParams } from "react-router-dom";
import { StubPage } from "@/shared/components/StubPage";

export function SquadPage() {
  const { slug } = useParams();
  return <StubPage title={`Squad: ${slug}`} />;
}
