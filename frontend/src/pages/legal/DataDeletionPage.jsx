import { LegalPage } from "../../components/legal/LegalPage";

export function DataDeletionPage() {
  return (
    <LegalPage eyebrow="Privacy" title="Data Deletion Instructions" updatedAt="September 21, 2026">
      <p>
        You can request deletion of personal information associated with a ChatCart-powered conversation at any time.
      </p>

      <section>
        <h2>How to request deletion</h2>
        <ol>
          <li>Send “delete my data” in the same Messenger or WhatsApp conversation you used with the business.</li>
          <li>If messaging is unavailable, call ChatCart at <a href="tel:+8801725126467">+880 1725-126467</a>.</li>
          <li>Identify the business or Page and the messaging account used for the conversation.</li>
          <li>Complete a reasonable identity check so we do not delete another customer&apos;s information.</li>
        </ol>
      </section>

      <section>
        <h2>What happens next</h2>
        <p>
          We will locate the relevant conversation and associated customer profile and delete or anonymize eligible
          information. We may retain limited order, fraud-prevention, security, or compliance records where required
          by law or needed to establish or defend legal claims. We will explain if any information cannot be deleted.
        </p>
      </section>

      <section>
        <h2>Facebook and WhatsApp data</h2>
        <p>
          This process deletes information controlled by ChatCart and the participating business. Information held
          independently by Meta remains subject to Meta&apos;s own account controls and privacy policies.
        </p>
      </section>

      <section>
        <h2>Contact</h2>
        <address>
          ChatCart<br />
          160/1, Middle Badda, Dhaka 1212, Bangladesh<br />
          Phone: <a href="tel:+8801725126467">+880 1725-126467</a>
        </address>
      </section>
    </LegalPage>
  );
}
