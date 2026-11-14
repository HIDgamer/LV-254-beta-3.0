import { BooleanLike } from 'common/react';
import { createSearch } from 'common/string';
import { useState } from 'react';

import { useBackend } from '../../backend';
import { Box, Button, Dimmer, Icon, Input, Section, Stack } from '../../components';
import { NtosWindow } from '../../layouts';
import { ChatScreen } from './ChatScreen';
import { NtChat, NtMessenger } from './types';

type NtosMessengerData = {
  owner?: NtMessenger;
  saved_chats: Record<string, NtChat>;
  messengers: Record<string, NtMessenger>;
  sort_by_job: BooleanLike;
  alert_silenced: BooleanLike;
  alert_able: BooleanLike;
  sending_and_receiving: BooleanLike;
  open_chat: string | null;
};

export const NtosMessenger = (props) => {
  const { data } = useBackend<NtosMessengerData>();
  const { saved_chats = {}, open_chat } = data;

  let content: React.JSX.Element;
  const openChat = open_chat ? saved_chats[open_chat] : undefined;
  if (!openChat) {
    content = <ContactsScreen />;
  } else {
    content = (
      <ChatScreen
        key={openChat.ref}
        canReply={openChat.can_reply}
        messages={openChat.messages}
        recipient={openChat.recipient}
        unreads={openChat.unread_messages}
        chatRef={openChat.ref}
        draft={openChat.message_draft}
      />
    );
  }

  return (
    <NtosWindow width={500} height={650}>
      <NtosWindow.Content>{content}</NtosWindow.Content>
    </NtosWindow>
  );
};

const ContactsScreen = (props) => {
  const { act, data } = useBackend<NtosMessengerData>();
  const {
    owner,
    alert_silenced,
    alert_able,
    sending_and_receiving,
    saved_chats = {},
    messengers = {},
    sort_by_job,
  } = data;

  const [searchUser, setSearchUser] = useState('');

  const searchChat = createSearch(
    searchUser,
    (chat: NtChat) => chat.recipient.name + chat.recipient.job,
  );
  const searchMessenger = createSearch(
    searchUser,
    (messenger: NtMessenger) => messenger.name + messenger.job,
  );

  const chats = Object.values(saved_chats)
    .filter(searchChat)
    .sort((a, b) => b.unread_messages - a.unread_messages);

  const recentChatButtons = chats
    .filter((chat) => chat.visible)
    .map((chat) => (
      <ChatButton
        key={chat.ref}
        name={`${chat.recipient.name} (${chat.recipient.job})`}
        chatRef={chat.ref}
        unreads={chat.unread_messages}
      />
    ));

  const messengerButtons = Object.entries(messengers)
    .filter(
      ([ref, messenger]) =>
        chats.every((chat) => chat.recipient.ref !== ref) &&
        searchMessenger(messenger),
    )
    .map(([ref, messenger]) => (
      <ChatButton
        key={ref}
        name={`${messenger.name} (${messenger.job})`}
        chatRef={ref}
        unreads={0}
      />
    ))
    .concat(
      chats
        .filter((chat) => !chat.visible)
        .map((chat) => (
          <ChatButton
            key={chat.ref}
            name={`${chat.recipient.name} (${chat.recipient.job})`}
            chatRef={chat.ref}
            unreads={chat.unread_messages}
          />
        )),
    );

  return (
    <Stack fill vertical>
      <Stack.Item>
        <Section>
          <Stack vertical textAlign="center">
            <Box bold>
              <Icon name="address-card" mr={1} />
              Direct Messenger
            </Box>
            <Stack fill mt={0.5}>
              <Stack.Item grow>
                <Button
                  fluid
                  icon="bell"
                  disabled={!alert_able}
                  content={
                    alert_able && !alert_silenced ? 'Ringer: On' : 'Ringer: Off'
                  }
                  onClick={() => act('PDA_toggleAlerts')}
                />
              </Stack.Item>
              <Stack.Item grow>
                <Button
                  fluid
                  icon="address-card"
                  content={
                    sending_and_receiving
                      ? 'Send / Receive: On'
                      : 'Send / Receive: Off'
                  }
                  onClick={() => act('PDA_toggleSendingAndReceiving')}
                />
              </Stack.Item>
              <Stack.Item grow>
                <Button
                  fluid
                  icon="sort"
                  content={`Sort by: ${sort_by_job ? 'Job' : 'Name'}`}
                  onClick={() => act('PDA_changeSortStyle')}
                />
              </Stack.Item>
            </Stack>
          </Stack>
          <Stack justify="space-between" mt={1}>
            <Box m={0.5}>
              <Icon name="magnifying-glass" mr={0.5} />
              Search For User
            </Box>
            <Input
              width="220px"
              placeholder="Search by name or job..."
              value={searchUser}
              onInput={(_, value) => setSearchUser(value)}
            />
          </Stack>
        </Section>
      </Stack.Item>
      {recentChatButtons.length > 0 && (
        <Stack.Item grow={1}>
          <Stack vertical fill>
            <Section>
              <Icon name="comments" mr={1} />
              Previous Messages
            </Section>
            <Section fill scrollable>
              <Stack vertical>{recentChatButtons}</Stack>
            </Section>
          </Stack>
        </Stack.Item>
      )}
      <Stack.Item grow={2}>
        <Stack vertical fill>
          <Section>
            <Box m={0.5}>
              <Icon name="address-card" mr={1} />
              Detected Messengers
            </Box>
          </Section>
          <Section fill scrollable>
            <Stack vertical pb={1} fill>
              {messengerButtons.length === 0 && (
                <Stack align="center" justify="center" fill pl={4}>
                  <Icon color="gray" name="user-slash" size={2} />
                  <Stack.Item fontSize={1.5} ml={3}>
                    No users found.
                  </Stack.Item>
                </Stack>
              )}
              {messengerButtons}
            </Stack>
          </Section>
        </Stack>
      </Stack.Item>
      {!owner && <NoIDDimmer />}
    </Stack>
  );
};

type ChatButtonProps = {
  name: string;
  unreads: number;
  chatRef: string;
};

const ChatButton = (props: ChatButtonProps) => {
  const { act } = useBackend();
  const hasUnreads = props.unreads > 0;
  return (
    <Button
      icon={hasUnreads ? 'envelope' : undefined}
      fluid
      onClick={() => act('PDA_viewMessages', { ref: props.chatRef })}
    >
      {hasUnreads &&
        `[${props.unreads <= 9 ? props.unreads : '9+'} unread message${
          props.unreads !== 1 ? 's' : ''
        }] `}
      {props.name}
    </Button>
  );
};

const NoIDDimmer = () => {
  return (
    <Dimmer>
      <Stack align="baseline" vertical>
        <Stack ml={-2}>
          <Icon color="red" name="address-card" size={10} />
        </Stack>
        <Stack.Item fontSize="18px">
          Please imprint an ID to continue.
        </Stack.Item>
      </Stack>
    </Dimmer>
  );
};
