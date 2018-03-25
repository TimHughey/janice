import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { RemoteTableComponent } from './remote-table.component';

describe('RemoteTableComponent', () => {
  let component: RemoteTableComponent;
  let fixture: ComponentFixture<RemoteTableComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ RemoteTableComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(RemoteTableComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
