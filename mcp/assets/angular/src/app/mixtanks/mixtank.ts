export interface Mixtank {
  id: number;
  name: string;
  comment: string;
  enabled: boolean;
  sensor: string;
  referenceSensor: string;
  pump: string;
  air: string;
  heater: string;
  fill: string;
  replenish: string;
  insertedAt: string;
  updatedAt: string;
  profileNames: string[];
  activeProfile: string;
  state: string;
}
