import { Save } from "lucide-react";
import { Button } from "@/shared/components/ui/Button";
import { Select, Input } from "@/shared/components/ui/Field";
import { SectionCard } from "@/shared/components/ui/Card";

export function PresetsSection({
  presetNames,
  selectedPreset,
  presetNameInput,
  onSelectPreset,
  onPresetNameInputChange,
  onSavePreset,
  onDeletePreset,
}: {
  presetNames: string[];
  selectedPreset: string;
  presetNameInput: string;
  onSelectPreset: (name: string) => void;
  onPresetNameInputChange: (value: string) => void;
  onSavePreset: () => void;
  onDeletePreset: () => void;
}) {
  return (
    <SectionCard title="Presets" icon={<Save size={14} className="text-primary" />}>
      <div className="space-y-2.5">
        <Select value={selectedPreset} onChange={(e) => onSelectPreset(e.target.value)}>
          <option value="">Selecione um preset...</option>
          {presetNames.map((name) => (
            <option key={name} value={name}>
              {name}
            </option>
          ))}
        </Select>
        <Button variant="secondary" size="sm" onClick={onDeletePreset} disabled={!selectedPreset} className="w-full">
          Excluir preset
        </Button>
        <div className="flex gap-2">
          <Input
            value={presetNameInput}
            onChange={(e) => onPresetNameInputChange(e.target.value)}
            placeholder={selectedPreset || "Nome do preset"}
            className="flex-1"
          />
          <Button size="sm" onClick={onSavePreset} disabled={!presetNameInput.trim() && !selectedPreset}>
            Salvar
          </Button>
        </div>
      </div>
    </SectionCard>
  );
}
