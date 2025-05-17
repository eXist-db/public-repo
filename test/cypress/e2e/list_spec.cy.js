/* global cy */
/// <reference types="cypress" />

describe('list page', () => {
    beforeEach(() => {
        cy.visit('list')
    })

    it('should contain a navigation bar with 5 entries', () => {
        cy.navBar
    })

    it('should have the page title', () => {
        cy.get('h1').contains('Available Packages')
    })

    it('should have an list of packages', () => {
        cy.get('.package-list').should('exist')
    })

    it('should show the search form in the nav bar', () => {
        cy.get('#header-search').should('exist')
    })

})