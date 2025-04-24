/* global cy */
/// <reference types="cypress" />

describe('admin page', () => {
    beforeEach(() => {
        cy.visit('admin')
    })

    it('should contain a navigation bar with 5 entries', () => {
        cy.navBar
    })

    it('should show the login', () => {
        cy.get('h1').contains('Administrator Login')
    })

    // TODO
    // login
    // upload
})