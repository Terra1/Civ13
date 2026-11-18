import React from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, screen } from '@testing-library/react';
import { render } from '../testing';
import type { Data, ScreenProps } from '../types';
import { WiremodCircuit } from './WiremodCircuit';

afterEach(cleanup);

const ui = (data: Data = {}): ScreenProps => ({
  template: 'wiremod_circuit.tmpl',
  interactive: true,
  act: vi.fn(),
  data: {
    display_name: 'Integrated circuit',
    grid_mode: 1,
    screen_x: 0,
    screen_y: 0,
    component_catalog: [
      {
        type: '/obj/item/circuit_component/arithmetic',
        name: 'Arithmetic',
        description: 'Performs arithmetic.',
        category: 'Math',
        input_ports: [{ name: 'A', type: 'number', color: 'green' }],
        output_ports: [{ name: 'Result', type: 'number', color: 'green' }],
      },
    ],
    components: [
      {
        index: 1,
        type: '/obj/item/circuit_component/arithmetic',
        name: 'Arithmetic',
        description: 'Performs arithmetic.',
        category: 'Math',
        removable: 1,
        x: 30,
        y: 30,
        input_ports: [],
        output_ports: [
          {
            name: 'Result',
            type: 'number',
            color: 'green',
            ref: 'output-1-1',
          },
        ],
      },
      {
        index: 2,
        type: '/obj/item/circuit_component/arithmetic',
        name: 'Arithmetic',
        description: 'Performs arithmetic.',
        category: 'Math',
        removable: 1,
        x: 180,
        y: 80,
        input_ports: [
          {
            name: 'A',
            type: 'number',
            color: 'green',
            ref: 'input-2-1',
            connected_to: [],
            current_data: null,
          },
        ],
        output_ports: [],
      },
    ],
    ...data,
  },
});

describe('tgstation Wiremod circuit editor', () => {
  it('renders the original graph and connects compatible ports', () => {
    const props = ui();
    const view = render(<WiremodCircuit {...props} />);
    expect(view.container.querySelectorAll('.ObjectComponent')).toHaveLength(2);
    const ports = view.container.querySelectorAll('.ObjectComponent__Port');
    expect(ports).toHaveLength(2);

    fireEvent.mouseDown(ports[0], { button: 0, clientX: 100, clientY: 100 });
    fireEvent.mouseUp(ports[1], { button: 0, clientX: 200, clientY: 140 });

    expect(props.act).toHaveBeenLastCalledWith('add_connection', {
      input_port_id: 1,
      output_port_id: 1,
      input_component_id: 2,
      output_component_id: 1,
    });
  });

  it('loads the Civ13 core catalog into the original component menu', async () => {
    const view = render(<WiremodCircuit {...ui({ components: [] })} />);
    const buttons = view.container.querySelectorAll(
      '.wiremod-window__buttons .Button',
    );
    fireEvent.click(buttons[1]);

    expect(await screen.findByText('Component Menu')).toBeTruthy();
    expect(await screen.findByText('Arithmetic')).toBeTruthy();
  });

  it('renders variables in the original variable menu', async () => {
    const view = render(
      <WiremodCircuit
        {...ui({
          components: [],
          variables: [
            { name: 'score', datatype: 'number', color: 'green', is_list: 0 },
          ],
          global_basic_types: ['number', 'boolean', 'string', 'any'],
        })}
      />,
    );
    const buttons = view.container.querySelectorAll(
      '.wiremod-window__buttons .Button',
    );
    fireEvent.click(buttons[0]);

    expect(await screen.findByText('Variable Options')).toBeTruthy();
    expect(screen.getByText('score')).toBeTruthy();
  });

  it('adapts zoomed pointer coordinates when dragging a circuit component', () => {
    const props = ui();
    const view = render(<WiremodCircuit {...props} />);
    const zoomPlane = view.container.querySelector<HTMLElement>(
      '.wiremod-window__content [style*="scale("]',
    );
    expect(zoomPlane).toBeTruthy();
    zoomPlane!.style.transform = 'translate(0px, 0px) scale(2)';
    const titlebar = view.container.querySelector(
      '.ObjectComponent__Titlebar',
    );
    expect(titlebar).toBeTruthy();

    fireEvent.mouseDown(titlebar!, { button: 0, clientX: 100, clientY: 100 });
    fireEvent.mouseMove(window, { clientX: 100, clientY: 100 });
    fireEvent.mouseMove(window, { clientX: 180, clientY: 160 });
    fireEvent.mouseUp(titlebar!, { button: 0, clientX: 180, clientY: 160 });

    expect(props.act).toHaveBeenCalledWith('set_component_coordinates', {
      component_id: 1,
      rel_x: 70,
      rel_y: 60,
    });
  });
});
