import { BooleanLike } from 'common/react';
import { useEffect, useRef, useState } from 'react';

import { useBackend } from '../../backend';
import {
  Box,
  Button,
  Icon,
  Input,
  Section,
  Stack,
  Tooltip,
} from '../../components';
import { NtMessage, NtMessenger } from './types';

type ChatScreenProps = {
  canReply: BooleanLike;
  chatRef: string;
  draft: string;
  messages: NtMessage[];
  recipient: NtMessenger;
  unreads: number;
};

const READ_UNREADS_TIME_MS = 1000;
const SEND_COOLDOWN_MS = 1000;
const QUICK_REPLIES = ['Roger', 'On my way', 'Wait one', 'Negative', 'Need assistance'];

export const ChatScreen = (props: ChatScreenProps) => {
  const { act } = useBackend();
  const { canReply, messages, recipient, chatRef, unreads, draft } = props;

  const [message, setMessage] = useState(draft);
  const [inputKey, setInputKey] = useState(0);
  const [canSend, setCanSend] = useState(true);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const scroll = scrollRef.current;
    if (scroll) {
      scroll.scrollTop = scroll.scrollHeight;
    }
    if (unreads <= 0) {
      return;
    }
    const timeout = setTimeout(
      () => act('PDA_clearUnreads', { ref: chatRef }),
      READ_UNREADS_TIME_MS,
    );
    return () => clearTimeout(timeout);
  }, [messages.length]);

  const sendMessage = (text: string = message) => {
    if (text === '' || !canSend) {
      return;
    }
    act('PDA_sendMessage', { ref: chatRef, message: text });
    if (text === message) {
      setMessage('');
      setInputKey(inputKey + 1);
    }
    setCanSend(false);
    setTimeout(() => setCanSend(true), SEND_COOLDOWN_MS);
  };

  const closeChat = () => {
    act('PDA_saveMessageDraft', { ref: chatRef, message });
    act('PDA_viewMessages', { ref: null });
  };

  const filteredMessages: React.JSX.Element[] = [];
  for (let index = 0; index < messages.length; index++) {
    const entry = messages[index];
    const isSwitch = !(
      index === 0 || messages[index - 1].outgoing === entry.outgoing
    );

    if (index === messages.length - unreads) {
      filteredMessages.push(
        <ChatDivider key="unread-divider" mt={isSwitch ? 3 : 1} />,
      );
    }

    filteredMessages.push(
      <Stack.Item key={index} mt={isSwitch ? 3 : 1}>
        <ChatMessage
          outgoing={entry.outgoing}
          message={entry.message}
          timestamp={entry.timestamp}
        />
      </Stack.Item>,
    );
  }

  return (
    <Stack vertical fill>
      <Section>
        <Button icon="arrow-left" content="Back" onClick={closeChat} />
        <Button
          icon="box-archive"
          content="Close chat"
          onClick={() => act('PDA_closeMessages', { ref: chatRef })}
        />
        <Button.Confirm
          icon="trash-can"
          content="Delete chat"
          onClick={() => act('PDA_clearMessages', { ref: chatRef })}
        />
      </Section>

      <Stack.Item grow={1}>
        <Section
          scrollable
          fill
          fitted
          title={`${recipient.name} (${recipient.job})`}
          ref={scrollRef}
        >
          <Stack vertical className="NtosChatLog">
            {!!(messages.length > 0 && canReply) && (
              <>
                <Stack.Item textAlign="center" fontSize={1}>
                  This is the beginning of your chat with {recipient.name}.
                </Stack.Item>
                <Stack.Divider />
              </>
            )}
            {filteredMessages}
          </Stack>
        </Section>
      </Stack.Item>

      <Stack.Item>
        <Section fill>
          {canReply ? (
            <Stack vertical>
              <Stack.Item>
                <Stack wrap>
                  {QUICK_REPLIES.map((reply) => (
                    <Stack.Item key={reply}>
                      <Button
                        compact
                        disabled={!canSend}
                        onClick={() => sendMessage(reply)}
                      >
                        {reply}
                      </Button>
                    </Stack.Item>
                  ))}
                </Stack>
              </Stack.Item>
              <Stack.Item>
            <Stack fill align="center">
              <Stack.Item grow={1}>
                <Input
                  key={inputKey}
                  placeholder={`Send message to ${recipient.name}...`}
                  fluid
                  autoFocus
                  value={message}
                  maxLength={1024}
                  onInput={(_, value) => setMessage(value)}
                  onEnter={(_, value) => sendMessage(value)}
                />
              </Stack.Item>
              <Stack.Item>
                <Button
                  tooltip="Send"
                  icon="arrow-right"
                  onClick={() => sendMessage()}
                  disabled={!canSend}
                />
              </Stack.Item>
            </Stack>
              </Stack.Item>
            </Stack>
          ) : (
            <Box width="100%" italic color="gray" ml={1}>
              You cannot reply to this user.
            </Box>
          )}
        </Section>
      </Stack.Item>
    </Stack>
  );
};

type ChatMessageProps = {
  outgoing: BooleanLike;
  message: string;
  timestamp: string;
};

const ChatMessage = (props: ChatMessageProps) => {
  const { message, outgoing, timestamp } = props;

  return (
    <Box className={`NtosChatMessage${outgoing ? '_outgoing' : ''}`}>
      <Box className="NtosChatMessage__content">
        <Box as="span">{message}</Box>
        <Tooltip content={timestamp} position={outgoing ? 'left' : 'right'}>
          <Icon
            className="NtosChatMessage__timestamp"
            name="clock-o"
            size={0.8}
          />
        </Tooltip>
      </Box>
    </Box>
  );
};

const ChatDivider = (props: { readonly mt: number }) => {
  return (
    <Box className="UnreadDivider" m={0} mt={props.mt}>
      <div />
      <span>Unread Messages</span>
      <div />
    </Box>
  );
};
