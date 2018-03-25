import { Component, OnInit } from '@angular/core';
import { Input, Output } from '@angular/core';

import { MenuItem } from 'primeng/api';

@Component({
  selector: 'app-landing',
  templateUrl: './landing.component.html',
  styleUrls: ['./landing.component.css']
})
export class LandingComponent implements OnInit {

  title: String = 'Janice';

  constructor() { }

  private items: MenuItem[];

  @Output() disabled = true;
  @Input() greet: string;
  @Output() displayName: string;

  handleClick() {
    this.displayName = this.greet;
    this.disabled = true;
  }

  nameChanged({ target }) { }

  input({ target }) {
    this.disabled = (this.greet.length > 2) ? false : true;
  }

  ngOnInit() {
    this.items = [{ label: 'Janice', styleClass: 'fancy-font' }];
  }

}
