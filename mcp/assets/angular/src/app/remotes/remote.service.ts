import { Injectable } from '@angular/core';
import { Http, Response } from '@angular/http';

import { Remote } from './remote';

@Injectable()
export class RemoteService {

  private remotes = [
    {
      id: 0, name: 'lab-switches', host: 'mcr.30aea427b684', hardware: 'esp32',
      firmware: '1111111', firmwarePref: 'head', atVersion: true, startedAt: '10min',
      seenAt: '10min'
    },
    {
      id: 1, name: 'lab-sensors', host: 'mcr.30aea4287f40', hardware: 'esp32',
      firmware: '1111111', firmwarePref: 'head', atVersion: true, startedAt: '11min',
      seenAt: '11min'
    },
  ];

  constructor() { }

  getRemotes(): Remote[] {
    return this.remotes;
  }

}
