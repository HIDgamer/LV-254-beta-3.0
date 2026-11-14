import { BooleanLike } from 'common/react';
import { useState } from 'react';

import { useBackend } from '../backend';
import { Button, Section, TextArea } from '../components';
import { NtosWindow } from '../layouts';

type Data = {
  note: string;
  can_print: BooleanLike;
};

export const NtosNotepad = (props) => {
  const { act, data } = useBackend<Data>();
  const [note, setNote] = useState(data.note);

  const print = () => {
    act('UpdateNote', { newnote: note });
    act('PrintNote');
  };

  return (
    <NtosWindow width={400} height={480}>
      <NtosWindow.Content>
        <Section
          fill
          title="Notepad"
          buttons={
            !!data.can_print && (
              <Button icon="print" onClick={print}>
                Print
              </Button>
            )
          }
        >
          <TextArea
            fluid
            height="100%"
            value={note}
            maxLength={4096}
            onInput={(_, value) => setNote(value)}
            onChange={(_, value) => act('UpdateNote', { newnote: value })}
          />
        </Section>
      </NtosWindow.Content>
    </NtosWindow>
  );
};
