/* global cy */
/// <reference types="cypress" />

describe('search page', () => {
    beforeEach(() => {
        cy.visit('search')
    })

    it('should contain a navigation bar with 5 entries', () => {
        cy.navBar
    })

    it('should have the page title', () => {
        cy.get('h1').contains('Package Search')
    })

    it('should not show the search form in the nav bar', () => {
        cy.get('#header-search').should('not.exist')
    })

})