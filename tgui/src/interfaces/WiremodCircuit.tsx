import { useEffect } from 'react';

import { setWiremodComponentCatalog } from '../assets';
import { setBackendState } from '../backend';
import type { Data, Params, ScreenProps } from '../types';
import { IntegratedCircuit } from './IntegratedCircuit/index.jsx';

type ZoomedMouseEvent = MouseEvent & {
  screenZoomX?: number;
  screenZoomY?: number;
};

const getPlaneZoom = () => {
  const plane = document.querySelector<HTMLElement>(
    '.wiremod-window__content [style*="scale("]',
  );
  const match = plane?.style.transform.match(/scale\(([^)]+)\)/);
  const zoom = Number(match?.[1]);
  return Number.isFinite(zoom) && zoom > 0 ? zoom : 1;
};

export const WiremodCircuit = (props: ScreenProps) => {
  const catalog = Array.isArray(props.data.component_catalog)
    ? (props.data.component_catalog as Data[])
    : [];
  const data = {
    ...props.data,
    components: Array.isArray(props.data.components) ? props.data.components : [],
    variables: Array.isArray(props.data.variables) ? props.data.variables : [],
    global_basic_types: Array.isArray(props.data.global_basic_types)
      ? props.data.global_basic_types
      : [],
    stored_designs:
      props.data.stored_designs ??
      Object.fromEntries(catalog.map((component) => [component.type, true])),
    component_catalog: catalog,
  };
  const act = (action: string, params: Params = {}) => {
    const adjusted = { ...params };
    const content = document.querySelector<HTMLElement>(
      '.wiremod-window__content',
    );
    if (action === 'set_examined_component' && content) {
      const bounds = content.getBoundingClientRect();
      adjusted.x = Number(adjusted.x) - bounds.left;
      adjusted.y = Number(adjusted.y) - bounds.top;
    }
    props.act(action, adjusted);
  };

  setBackendState(data, act);
  setWiremodComponentCatalog(catalog);

  useEffect(() => {
    const addZoomedCoordinates = (event: MouseEvent) => {
      const zoom = getPlaneZoom();
      const adjusted = event as ZoomedMouseEvent;
      adjusted.screenZoomX = event.clientX / zoom || Number.EPSILON;
      adjusted.screenZoomY = event.clientY / zoom || Number.EPSILON;
    };
    window.addEventListener('mousemove', addZoomedCoordinates, true);
    return () =>
      window.removeEventListener('mousemove', addZoomedCoordinates, true);
  }, []);

  return <IntegratedCircuit />;
};
