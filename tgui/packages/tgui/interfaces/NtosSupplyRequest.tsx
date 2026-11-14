import { useState } from 'react';

import { useBackend } from '../backend';
import {
  Box,
  Button,
  Dropdown,
  Input,
  NoticeBox,
  Section,
  Stack,
  Tabs,
} from '../components';
import { NtosWindow } from '../layouts';

type Pack = {
  name: string;
  cost: number;
  category: string;
  type: string;
  contents: string[];
};

type CartEntry = {
  type: string;
  name: string;
  cost: number;
  quantity: number;
};

type OrderEntry = {
  num: number;
  reason: string;
  status: string;
};

type Data = {
  categories: string[];
  packs: Pack[];
  points: number;
  message: string | null;
  max_pack_quantity: number;
  cart: CartEntry[];
  cart_cost: number;
  orders: OrderEntry[];
};

enum Tab {
  Catalog,
  Cart,
  Requests,
}

export const NtosSupplyRequest = (props) => {
  const { act, data } = useBackend<Data>();
  const {
    categories = [],
    packs = [],
    points,
    message,
    max_pack_quantity,
    cart = [],
    cart_cost,
    orders = [],
  } = data;

  const [tab, setTab] = useState(Tab.Catalog);
  const [category, setCategory] = useState(categories[0]);
  const [search, setSearch] = useState('');
  const [reason, setReason] = useState('');
  const [reasonKey, setReasonKey] = useState(0);

  const query = search.toLowerCase();
  const visiblePacks = packs.filter((pack) =>
    query
      ? pack.name.toLowerCase().includes(query)
      : pack.category === category,
  );
  const quantityOf = (type: string) =>
    cart.find((entry) => entry.type === type)?.quantity || 0;
  const cartCount = cart.reduce((total, entry) => total + entry.quantity, 0);

  const submit = () => {
    act('submit', { reason });
    setReason('');
    setReasonKey(reasonKey + 1);
    setTab(Tab.Requests);
  };

  return (
    <NtosWindow width={450} height={600}>
      <NtosWindow.Content>
        <Stack vertical fill>
          {!!message && (
            <Stack.Item>
              <NoticeBox info>
                <Stack align="center">
                  <Stack.Item grow>{message}</Stack.Item>
                  <Stack.Item>
                    <Button compact onClick={() => act('acknowledged')}>
                      OK
                    </Button>
                  </Stack.Item>
                </Stack>
              </NoticeBox>
            </Stack.Item>
          )}
          <Stack.Item>
            <Tabs fluid>
              <Tabs.Tab
                selected={tab === Tab.Catalog}
                onClick={() => setTab(Tab.Catalog)}
              >
                Catalog
              </Tabs.Tab>
              <Tabs.Tab
                selected={tab === Tab.Cart}
                onClick={() => setTab(Tab.Cart)}
              >
                Cart ({cartCount})
              </Tabs.Tab>
              <Tabs.Tab
                selected={tab === Tab.Requests}
                onClick={() => setTab(Tab.Requests)}
              >
                Requests
              </Tabs.Tab>
            </Tabs>
          </Stack.Item>
          <Stack.Item grow>
            {tab === Tab.Catalog && (
              <Section fill scrollable title={`Points: ${points}`}>
                <Stack vertical>
                  <Stack.Item>
                    <Dropdown
                      width="100%"
                      options={categories}
                      selected={category}
                      onSelected={(value) => setCategory(value)}
                    />
                  </Stack.Item>
                  <Stack.Item>
                    <Input
                      fluid
                      value={search}
                      placeholder="Search all categories..."
                      onInput={(_, value) => setSearch(value)}
                    />
                  </Stack.Item>
                  {visiblePacks.map((pack) => (
                    <Stack.Item key={pack.type}>
                      <Stack align="center">
                        <Stack.Item grow>
                          <Box bold>{pack.name}</Box>
                          <Box color="label" fontSize={0.9}>
                            {pack.contents.join(', ')}
                          </Box>
                        </Stack.Item>
                        <Stack.Item>{pack.cost} pts</Stack.Item>
                        <Stack.Item>
                          <Button
                            icon="plus"
                            disabled={
                              quantityOf(pack.type) >= max_pack_quantity
                            }
                            onClick={() =>
                              act('adjust_cart', {
                                pack: pack.type,
                                to: quantityOf(pack.type) + 1,
                              })
                            }
                          />
                        </Stack.Item>
                      </Stack>
                    </Stack.Item>
                  ))}
                </Stack>
              </Section>
            )}
            {tab === Tab.Cart && (
              <Section fill scrollable title={`Cart: ${cart_cost} pts`}>
                <Stack vertical>
                  {!cart.length && (
                    <Stack.Item color="label">The cart is empty.</Stack.Item>
                  )}
                  {cart.map((entry) => (
                    <Stack.Item key={entry.type}>
                      <Stack align="center">
                        <Stack.Item grow>{entry.name}</Stack.Item>
                        <Stack.Item>
                          <Button
                            icon="minus"
                            onClick={() =>
                              act('adjust_cart', {
                                pack: entry.type,
                                to: entry.quantity - 1,
                              })
                            }
                          />
                        </Stack.Item>
                        <Stack.Item>{entry.quantity}</Stack.Item>
                        <Stack.Item>
                          <Button
                            icon="plus"
                            disabled={entry.quantity >= max_pack_quantity}
                            onClick={() =>
                              act('adjust_cart', {
                                pack: entry.type,
                                to: entry.quantity + 1,
                              })
                            }
                          />
                        </Stack.Item>
                        <Stack.Item>
                          {entry.cost * entry.quantity} pts
                        </Stack.Item>
                      </Stack>
                    </Stack.Item>
                  ))}
                  <Stack.Item>
                    <Input
                      key={reasonKey}
                      fluid
                      value={reason}
                      maxLength={200}
                      placeholder="Reason for the request..."
                      onInput={(_, value) => setReason(value)}
                    />
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="paper-plane"
                      disabled={!cart.length || !reason.length}
                      onClick={submit}
                    >
                      Send request
                    </Button>
                    <Button
                      icon="trash"
                      disabled={!cart.length}
                      onClick={() => act('discard_cart')}
                    >
                      Discard cart
                    </Button>
                  </Stack.Item>
                </Stack>
              </Section>
            )}
            {tab === Tab.Requests && (
              <Section fill scrollable title="Your requests">
                <Stack vertical>
                  {!orders.length && (
                    <Stack.Item color="label">No requests sent yet.</Stack.Item>
                  )}
                  {orders.map((order) => (
                    <Stack.Item key={order.num}>
                      <Box bold>
                        #{order.num} - {order.status}
                      </Box>
                      <Box color="label">{order.reason}</Box>
                    </Stack.Item>
                  ))}
                </Stack>
              </Section>
            )}
          </Stack.Item>
        </Stack>
      </NtosWindow.Content>
    </NtosWindow>
  );
};
