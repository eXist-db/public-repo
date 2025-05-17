/* global cy */
/// <reference types="cypress" />

describe('landing page', () => {
    beforeEach(() => {
        cy.visit('')
    })

    it('should contain a navigation bar with 5 entries', () => {
        cy.navBar
    })

    it('should have the default main title', () => {
        cy.get('h1.hero').contains('EXpath Package Registry')
    })

    it('should have an Installation section', () => {
        cy.get('#installation > h2').contains('Installation')
    })

    it('should not show the search form in the nav bar', () => {
        cy.get('#header-search').should('not.exist')
    })

})