import { useBackend } from '../backend';
import { Button, Section, Stack } from '../components';
import { NtosWindow } from '../layouts';

type ThemeInfo = {
  theme_name: string;
  theme_ref: string;
};

type Data = {
  PC_device_theme: string;
  themes: ThemeInfo[];
};

export const NtosThemeConfigure = (props) => {
  const { act, data } = useBackend<Data>();
  const { PC_device_theme, themes = [] } = data;

  return (
    <NtosWindow width={400} height={170 + themes.length * 34}>
      <NtosWindow.Content scrollable>
        <Section title="Theme">
          <Stack vertical>
            {themes.map((theme) => (
              <Stack.Item key={theme.theme_name}>
                <Button.Checkbox
                  fluid
                  checked={theme.theme_ref === PC_device_theme}
                  onClick={() =>
                    act('PRG_change_theme', {
                      selected_theme: theme.theme_name,
                    })
                  }
                >
                  {theme.theme_name}
                </Button.Checkbox>
              </Stack.Item>
            ))}
          </Stack>
        </Section>
      </NtosWindow.Content>
    </NtosWindow>
  );
};
