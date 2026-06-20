import { useParams } from "react-router-dom";
import { StubPage } from "@/shared/components/StubPage";

export function FlowPage() {
  const { slug } = useParams();
  return <StubPage title={`Flow: ${slug}`} />;
}
