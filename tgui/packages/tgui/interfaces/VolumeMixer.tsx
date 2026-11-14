import { useBackend } from '../backend';
import { LabeledList, Section, Slider } from '../components';
import { Window } from '../layouts';

type Category = {
  id: number;
  name: string;
};

type Data = {
  categories: Category[];
  volumes: Record<string, number>;
};

export const VolumeMixer = () => {
  const { act, data } = useBackend<Data>();
  const { categories = [], volumes = {} } = data;

  return (
    <Window title="Volume Mixer" width={380} height={80 + categories.length * 32}>
      <Window.Content scrollable>
        <Section>
          <LabeledList>
            {categories.map((category) => (
              <LabeledList.Item key={category.id} label={category.name}>
                <Slider
                  minValue={0}
                  maxValue={100}
                  step={1}
                  stepPixelSize={2}
                  value={volumes[category.id] ?? 100}
                  format={(value) => `${Math.round(value)}%`}
                  onChange={(_, value) =>
                    act('set_volume', {
                      category: category.id,
                      volume: Math.round(value),
                    })
                  }
                />
              </LabeledList.Item>
            ))}
          </LabeledList>
        </Section>
      </Window.Content>
    </Window>
  );
};
