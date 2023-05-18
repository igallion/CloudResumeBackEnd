describe('Cloud Resume Spec', () => {
  it('passes', () => {
    cy.visit('https://www.ilgallion.com/index.html')
    cy.location().should((page) => {
      expect(page.hostname).to.equal('www.ilgallion.com');
      expect(page.protocol).to.equal('https:');
    });
    cy.title().should('contain', 'Resume');
    cy.contains('Isaac Gallion Resume');
    let n = Number(0)
    let n2 = Number(2)
    cy.request({
      method: 'GET',
      url: "https://h0d6a8xs0g.execute-api.us-east-1.amazonaws.com/CloudResumeCounterTerraform",

    })
      .then((response) => {
        cy.log(JSON.stringify(response.body))
        expect(response.status).to.equal(200)
        expect(response.body.Attributes.Quantity.N).to.not.be.oneOf([null, ""])
        n = n + Number(response.body.Attributes.Quantity.N)
        cy.log("This is n " + n)
        cy.request({
          method: 'GET',
          url: "https://h0d6a8xs0g.execute-api.us-east-1.amazonaws.com/CloudResumeCounterTerraform"
        })
        .then((response2) => {
          expect(response2.status).to.equal(200)
          n2 = n2 + n
          expect(Number(response2.body.Attributes.Quantity.N)).to.equal(n2)
        })
      });
  })
})