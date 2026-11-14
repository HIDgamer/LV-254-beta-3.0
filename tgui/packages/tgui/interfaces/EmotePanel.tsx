import { BooleanLike } from 'common/react';
import { capitalizeFirst } from 'common/string';
import { useState } from 'react';

import { useBackend } from '../backend';
import { Box, Button, Flex, Icon, Input, Section } from '../components';
import { Window } from '../layouts';

type Emote = {
  key: string;
  name: string;
  hands: BooleanLike;
  visible: BooleanLike;
  audible: BooleanLike;
  sound: BooleanLike;
  use_params: BooleanLike;
};

type EmotePanelData = {
  emotes: Emote[];
};

type Filters = {
  visible: boolean;
  audible: boolean;
  sound: boolean;
  hands: boolean;
  use_params: boolean;
};

const FILTER_BUTTONS: { key: keyof Filters; icon: string; tooltip: string }[] = [
  { key: 'visible', icon: 'eye', tooltip: 'Visible' },
  { key: 'audible', icon: 'comment', tooltip: 'Audible' },
  { key: 'sound', icon: 'volume-up', tooltip: 'Sound' },
  { key: 'hands', icon: 'hand-paper', tooltip: 'Hands' },
  { key: 'use_params', icon: 'crosshairs', tooltip: 'Params' },
];

export const EmotePanel = () => {
  const { act, data } = useBackend<EmotePanelData>();
  const { emotes = [] } = data;

  const [filters, setFilters] = useState<Filters>({
    visible: false,
    audible: false,
    sound: false,
    hands: false,
    use_params: false,
  });
  const [searchText, setSearchText] = useState('');
  const [useParams, setUseParams] = useState(false);
  const [showNames, setShowNames] = useState(true);
  const [showIcons, setShowIcons] = useState(false);

  const search = searchText.toLowerCase();
  const shown = emotes
    .filter(
      (emote) =>
        emote.key &&
        (!search ||
          emote.key.toLowerCase().includes(search) ||
          emote.name.toLowerCase().includes(search)) &&
        FILTER_BUTTONS.every(({ key }) => !filters[key] || emote[key]),
    )
    .sort((a, b) => (a.name > b.name ? 1 : -1));

  return (
    <Window width={630} height={500}>
      <Window.Content scrollable>
        <Section
          title="Filters"
          buttons={FILTER_BUTTONS.map(({ key, icon, tooltip }) => (
            <Button
              key={key}
              icon={icon}
              tooltip={tooltip}
              selected={filters[key]}
              onClick={() => setFilters({ ...filters, [key]: !filters[key] })}
            />
          ))}
        >
          <Input
            fluid
            placeholder="Search all emotes..."
            value={searchText}
            onInput={(_, value) => setSearchText(value)}
          />
        </Section>
        <Section
          title={searchText ? `Search results of "${searchText}"` : 'All Emotes'}
          buttons={
            <>
              <Button onClick={() => setShowNames(!showNames)}>
                {showNames ? 'Show Names' : 'Show Keys'}
              </Button>
              <Button selected={showIcons} onClick={() => setShowIcons(!showIcons)}>
                Show Icons
              </Button>
              <Button
                icon="crosshairs"
                selected={useParams}
                onClick={() => setUseParams(!useParams)}
              >
                Use Params
              </Button>
            </>
          }
        >
          <Flex wrap>
            {shown.map((emote) => (
              <Flex.Item key={emote.key}>
                <Button
                  width={showIcons ? 16 : 8}
                  tooltip={showIcons ? '' : <EmoteIcons emote={emote} margin={0.5} />}
                  onClick={() =>
                    act('play_emote', {
                      emote_key: emote.key,
                      use_params: useParams,
                    })
                  }
                >
                  <Box inline width="50%">
                    {showNames
                      ? capitalizeFirst(emote.name.toLowerCase())
                      : emote.key}
                  </Box>
                  {showIcons && <EmoteIcons emote={emote} margin={0} />}
                </Button>
              </Flex.Item>
            ))}
          </Flex>
        </Section>
      </Window.Content>
    </Window>
  );
};

const EmoteIcons = (props: { readonly emote: Emote; readonly margin: number }) => {
  const { emote, margin } = props;

  return (
    <Box inline>
      {FILTER_BUTTONS.map(({ key, icon }) => (
        <Icon
          key={key}
          name={icon}
          m={margin}
          color={!emote[key] ? 'red' : ''}
          opacity={!emote[key] ? 0.5 : 1}
        />
      ))}
    </Box>
  );
};
