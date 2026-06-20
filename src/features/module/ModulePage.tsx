import { useParams } from "react-router-dom";
import { StubPage } from "@/shared/components/StubPage";

export function ModulePage() {
  const { slug } = useParams();
  return <StubPage title={`Module: ${slug}`} />;
}
