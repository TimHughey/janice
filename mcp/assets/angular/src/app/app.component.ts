import { Component } from '@angular/core';
import { Input, Output } from '@angular/core';
import { OnInit } from '@angular/core';

import { ButtonModule } from 'primeng/primeng';
import { ConfirmationService, Message } from 'primeng/api';

import { MenuItem } from 'primeng/api';


@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent implements OnInit {
  title = 'Janice';
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
