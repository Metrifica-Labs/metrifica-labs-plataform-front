CREATE TABLE IF NOT EXISTS copy_sessions (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  persona_id UUID REFERENCES personas(id) ON DELETE CASCADE,
  agent_slug TEXT NOT NULL DEFAULT 'copy-tools',
  messages   JSONB NOT NULL DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE copy_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY copy_sessions_org ON copy_sessions
  USING (org_id IN (
    SELECT org_id FROM organization_members WHERE user_id = auth.uid()
  ));