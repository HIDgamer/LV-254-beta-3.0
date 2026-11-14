import { useBackend } from '../backend';
import { Box, Button, LabeledList, Section, Stack, Table } from '../components';
import { NtosWindow } from '../layouts';
import { NTOSData } from '../layouts/NtosWindow';

export const NtosMain = (props) => {
  const { act, data } = useBackend<NTOSData>();
  const {
    show_imprint,
    programs = [],
    has_light,
    light_on,
    login,
    proposed_login,
  } = data;
  const headerPrograms = programs.filter((program) => program.header_program);
  const listedCount = programs.length - headerPrograms.length;
  const height = Math.min(
    700,
    252 + (headerPrograms.length ? 48 : 0) + listedCount * 32,
  );

  return (
    <NtosWindow title="PDA Interface" width={400} height={height}>
      <NtosWindow.Content scrollable>
        {headerPrograms.length > 0 && (
          <Section>
            <Stack wrap>
              {headerPrograms.map((app) => (
                <Stack.Item key={app.name}>
                  <Button
                    content={app.desc}
                    icon={app.icon}
                    onClick={() => act('PC_runprogram', { name: app.name })}
                  />
                </Stack.Item>
              ))}
            </Stack>
          </Section>
        )}
        <Section title="Details">
          <LabeledList>
            <LabeledList.Item label="ID Name">
              {show_imprint
                ? login.IDName +
                  ' ' +
                  (proposed_login.IDName ? `(${proposed_login.IDName})` : '')
                : (proposed_login.IDName ?? '')}
            </LabeledList.Item>
            <LabeledList.Item label="Assignment">
              {show_imprint
                ? login.IDJob +
                  ' ' +
                  (proposed_login.IDJob ? `(${proposed_login.IDJob})` : '')
                : (proposed_login.IDJob ?? '')}
            </LabeledList.Item>
          </LabeledList>
          <Box mt={1}>
            {!!has_light && (
              <Button
                icon="lightbulb"
                content="Flashlight"
                color={light_on ? 'good' : 'bad'}
                selected={light_on}
                onClick={() => act('PC_toggle_light')}
              />
            )}
            <Button
              icon="eject"
              content="Eject ID"
              disabled={!proposed_login.IDName}
              onClick={() => act('PC_Eject_Disk', { name: 'ID' })}
            />
            {!!show_imprint && (
              <Button
                icon="dna"
                content="Imprint ID"
                disabled={
                  !proposed_login.IDName ||
                  (proposed_login.IDName === login.IDName &&
                    proposed_login.IDJob === login.IDJob)
                }
                onClick={() => act('PC_Imprint_ID', { name: 'ID' })}
              />
            )}
          </Box>
        </Section>
        <ProgramsTable />
      </NtosWindow.Content>
    </NtosWindow>
  );
};

const ProgramsTable = (props) => {
  const { act, data } = useBackend<NTOSData>();
  const { programs = [] } = data;
  const listedPrograms = programs.filter((program) => !program.header_program);

  return (
    <Section title="Programs">
      <Table>
        {listedPrograms.map((program) => (
          <Table.Row key={program.name}>
            <Table.Cell>
              <Button
                fluid
                color={program.alert ? 'yellow' : 'transparent'}
                icon={program.icon}
                content={program.desc}
                onClick={() => act('PC_runprogram', { name: program.name })}
              />
            </Table.Cell>
            <Table.Cell collapsing width="18px">
              {!!program.running && (
                <Button
                  color="transparent"
                  icon="times"
                  tooltip="Close program"
                  tooltipPosition="left"
                  onClick={() => act('PC_killprogram', { name: program.name })}
                />
              )}
            </Table.Cell>
          </Table.Row>
        ))}
      </Table>
    </Section>
  );
};
