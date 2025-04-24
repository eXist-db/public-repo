/* global cy */
/// <reference types="cypress" />

describe('stats page', () => {
    beforeEach(() => {
        cy.visit('stats')
    })

    it('should contain a navigation bar with 5 entries', () => {
        cy.navBar
    })

    it('should have the page title', () => {
        cy.get('h1').contains('Statistics')
    })
})