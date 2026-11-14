import { useState } from 'react';

import { useBackend } from '../backend';
import { Input, Section, Table } from '../components';
import { NtosWindow } from '../layouts';

type Crew = {
  name: string;
  rank: string;
  squad?: string | null;
  is_active: string;
};

type Data = {
  manifest: Record<string, Crew[]>;
  departments_with_jobs: Record<string, string[]>;
};

const DEPARTMENT_ORDER = [
  'Command',
  'Auxiliary',
  'Security',
  'Engineering',
  'Requisitions',
  'Medical',
  'Miscellaneous',
];

export const NtosCrewManifest = (props) => {
  const { data } = useBackend<Data>();
  const { manifest = {}, departments_with_jobs = {} } = data;
  const [search, setSearch] = useState('');
  const query = search.toLowerCase();

  const departments = Object.keys(manifest).sort((a, b) => {
    const indexA = DEPARTMENT_ORDER.indexOf(a);
    const indexB = DEPARTMENT_ORDER.indexOf(b);
    return (
      (indexA === -1 ? Infinity : indexA) - (indexB === -1 ? Infinity : indexB)
    );
  });

  return (
    <NtosWindow width={450} height={600}>
      <NtosWindow.Content scrollable>
        <Section>
          <Input
            fluid
            value={search}
            placeholder="Search by name or rank..."
            onInput={(_, value) => setSearch(value)}
          />
        </Section>
        {departments.map((department) => {
          const roleOrder = departments_with_jobs[department] || [];
          const crew = (manifest[department] || [])
            .filter(
              (entry) =>
                entry.name.toLowerCase().includes(query) ||
                entry.rank.toLowerCase().includes(query),
            )
            .sort((a, b) => {
              const rankA = roleOrder.indexOf(a.rank);
              const rankB = roleOrder.indexOf(b.rank);
              return (
                (rankA === -1 ? Infinity : rankA) -
                (rankB === -1 ? Infinity : rankB)
              );
            });
          if (!crew.length) {
            return null;
          }
          return (
            <Section key={department} title={department}>
              <Table>
                {crew.map((entry) => (
                  <Table.Row key={entry.name} className="candystripe">
                    <Table.Cell bold>{entry.name}</Table.Cell>
                    <Table.Cell textAlign="right">({entry.rank})</Table.Cell>
                  </Table.Row>
                ))}
              </Table>
            </Section>
          );
        })}
      </NtosWindow.Content>
    </NtosWindow>
  );
};
